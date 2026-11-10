require "json"

module Translation
  # Exports only a fixed allowlist of already-stored translation data.
  # Never includes credentials, endpoint URLs, request headers or provider response snapshots.
  class ExportDocument
    def initialize(translation, runs)
      @translation = translation
      @runs = runs
    end

    def render(file_format)
      case file_format
      when "txt" then plain_text
      when "md" then markdown
      when "json" then JSON.pretty_generate(structured_data) + "\n"
      else raise ArgumentError, "Unsupported export format"
      end
    end

    private

    def structured_data
      {
        "schema_version" => "1.0",
        "session" => {
          "id" => @translation.id,
          "created_at" => @translation.created_at.utc.iso8601,
          "status" => @translation.status,
          "source_language" => @translation.source_language,
          "target_language" => @translation.target_language,
          "source_text" => @translation.source_text,
          "preserve_formatting" => @translation.preserve_formatting,
          "use_glossary" => @translation.use_glossary?,
          "glossary_terms" => @translation.glossary_terms,
          "preferred_model_key" => @translation.preferred_model&.model_key
        },
        "results" => @runs.map do |run|
          {
            "model_key" => run.translation_model.model_key,
            "model_name" => run.translation_model.display_name,
            "status" => run.status,
            "translation_text" => run.translation_text,
            "error_code" => run.error_code,
            "is_mock_result" => run.is_mock_result?,
            "preferred" => preferred?(run)
          }
        end
      }
    end

    def preferred?(run)
      run.status == "completed" && run.translation_model_id == @translation.preferred_model_id
    end

    def title
      I18n.t("history_export.session_title", id: @translation.id)
    end

    def metadata
      [
        [I18n.t("history_export.created_at"), @translation.created_at.utc.iso8601],
        [I18n.t("history_export.source_language"), @translation.source_language],
        [I18n.t("history_export.target_language"), @translation.target_language],
        [I18n.t("history_export.status"), @translation.status],
        [I18n.t("history_export.glossary_count"), @translation.glossary_terms.size]
      ]
    end

    def result_title(run)
      name = run.translation_model.display_name
      preferred = preferred?(run) ? " · #{I18n.t('history_export.preferred')}" : ""
      "#{name}#{preferred}"
    end

    def result_status(run)
      description = run.status
      description += " · #{I18n.t('history_export.simulated')}" if run.is_mock_result?
      description += " · #{run.error_code}" if run.error_code.present?
      description
    end

    def plain_text
      lines = [title, "=" * 48, ""]
      metadata.each { |name, value| lines << "#{name}: #{value}" }
      lines.concat(["", I18n.t("history_export.original"), "-" * 24, @translation.source_text, ""])
      @runs.each do |run|
        lines.concat([
          result_title(run),
          "-" * 24,
          "#{I18n.t('history_export.status')}: #{result_status(run)}",
          run.translation_text.presence || I18n.t("history_export.no_output"),
          ""
        ])
      end
      lines.join("\n").concat("\n")
    end

    # Fenced code preserves line breaks and cannot be prematurely closed by
    # backticks already present in the user's source or model output.
    def fenced(text)
      value = text.to_s
      longest = value.scan(/`+/).map(&:length).max || 0
      fence = "`" * [3, longest + 1].max
      "#{fence}text\n#{value}\n#{fence}"
    end

    def safe_heading(text)
      text.to_s.gsub(/[\\`*_{}\[\]<>()#+.!|]/) { |char| "\\#{char}" }
    end

    def markdown
      lines = ["# #{safe_heading(title)}", ""]
      metadata.each { |name, value| lines << "- **#{safe_heading(name)}:** #{safe_heading(value)}" }
      lines.concat(["", "## #{safe_heading(I18n.t('history_export.original'))}", "",
        fenced(@translation.source_text), ""])
      @runs.each do |run|
        lines.concat([
          "## #{safe_heading(result_title(run))}",
          "",
          "**#{safe_heading(I18n.t('history_export.status'))}:** #{safe_heading(result_status(run))}",
          "",
          fenced(run.translation_text.presence || I18n.t("history_export.no_output")),
          ""
        ])
      end
      lines.join("\n").concat("\n")
    end
  end
end
