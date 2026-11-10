module Translation
  # A snapshot of the relevant terminology is frozen when the user approves the
  # request; a subsequent glossary edit cannot modify an in-flight paid job.
  class GlossarySnapshot
    MAX_MATCHES = 20
    MAX_CANDIDATES = 2_000

    class InvalidSelection < StandardError; end

    def self.build(user:, source_language:, target_language:, source_text:)
      candidates = user.glossary_entries.where(active: true)
        .where("lower(source_language) = ? AND lower(target_language) = ?",
          source_language.strip.downcase, target_language.strip.downcase)
        .order(:id).limit(MAX_CANDIDATES + 1).to_a
      raise InvalidSelection, I18n.t("errors.glossary_too_many_entries") if candidates.size > MAX_CANDIDATES

      body = source_text.downcase(:fold)
      matched = candidates.select { |entry| body.include?(entry.source_term.downcase(:fold)) }
      raise InvalidSelection, I18n.t("errors.glossary_no_matches") if matched.empty?
      raise InvalidSelection, I18n.t("errors.glossary_too_many_matches", limit: MAX_MATCHES) if matched.size > MAX_MATCHES

      JSON.generate(matched.map do |entry|
        { "source" => entry.source_term, "target" => entry.target_term }
      end)
    end
  end
end
