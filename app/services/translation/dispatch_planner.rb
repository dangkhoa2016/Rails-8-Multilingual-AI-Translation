require "digest"

module Translation
  class DispatchPlanner
    class InvalidSelection < StandardError; end

    # Application safety cap; distinct from any inference adapter's contract.
    MAX_SOURCE_CODEPOINTS = 20_000
    ADAPTER_SOURCE_LIMITS = { "translation_gateway_v1" => 1_000 }.freeze

    def self.source_limit_for_adapter(adapter_key)
      ADAPTER_SOURCE_LIMITS[adapter_key]
    end

    def self.call(user:, source_text:, source_language:, target_language:, model_ids:, preserve_formatting:, client_request_key:, cost_approved:, use_glossary: false, ui_locale: I18n.locale.to_s)
      raise InvalidSelection, I18n.t("errors.cost_confirmation") unless cost_approved
      use_glossary = !!use_glossary
      model_ids = Array(model_ids).reject(&:blank?).map(&:to_i).uniq
      raise InvalidSelection, I18n.t("errors.model_count") unless model_ids.size.between?(1, 4)
      raise InvalidSelection, I18n.t("errors.request_key") unless client_request_key.to_s.match?(/\A[0-9a-f-]{36}\z/i)
      models = TranslationModel.where(id: model_ids).index_by(&:id)
      raise InvalidSelection, I18n.t("errors.model_selection") unless models.size == model_ids.size
      source_text = source_text.to_s
      source_language = source_language.to_s.strip
      target_language = target_language.to_s.strip
      unless source_text.present? && source_language.present? && target_language.present?
        raise InvalidSelection, I18n.t("errors.required_text_languages")
      end
      if source_language.downcase(:fold) == target_language.downcase(:fold)
        raise InvalidSelection, I18n.t("errors.different_languages")
      end
      if source_text.length > MAX_SOURCE_CODEPOINTS || source_language.length > 64 || target_language.length > 64
        raise InvalidSelection, I18n.t("errors.input_limit")
      end
      raise InvalidSelection, I18n.t("errors.printable_languages") unless [source_language, target_language].all? { |s| s.match?(/[\p{L}]/) && !s.match?(/[\p{Cc}\p{Cf}]/) }

      existing = user.translation_requests.find_by(client_request_key: client_request_key)
      return validate_replayed_request!(existing, model_ids, source_text, source_language, target_language, preserve_formatting, use_glossary) if existing

      dispatch_ids = []
      record = TranslationRequest.transaction do
        existing = user.translation_requests.find_by(client_request_key: client_request_key)
        next validate_replayed_request!(existing, model_ids, source_text, source_language, target_language, preserve_formatting, use_glossary) if existing

        # Reject the entire selection before storing a request or queuing any paid
        # provider POST: otherwise compatible models could incur charges even
        # though a selected Gateway v1 model cannot accept the source length.
        incompatible = model_ids.filter_map do |id|
          model = models.fetch(id)
          deployment = model.active? ? model.active_deployment : nil
          connection = deployment&.inference_connection
          next unless connection&.enabled? && connection.token_configured?
          limit = source_limit_for_adapter(connection.adapter_key)
          next unless limit && source_text.length > limit
          "#{model.display_name} (#{limit})"
        end
        if incompatible.any?
          raise InvalidSelection, I18n.t("errors.selected_models_input_limit", models: incompatible.join(", "))
        end

        glossary_snapshot = nil
        if use_glossary
          unsupported = model_ids.filter_map do |id|
            model = models.fetch(id)
            deployment = model.active? ? model.active_deployment : nil
            connection = deployment&.inference_connection
            next model.display_name unless connection&.enabled? && connection.token_configured?
            model.display_name unless connection.adapter_key == "openai_chat_completions"
          end
          if unsupported.any?
            raise InvalidSelection, I18n.t("errors.glossary_unsupported_adapter", models: unsupported.join(", "))
          end
          begin
            glossary_snapshot = Translation::GlossarySnapshot.build(
              user: user, source_language: source_language, target_language: target_language,
              source_text: source_text)
          rescue Translation::GlossarySnapshot::InvalidSelection => e
            raise InvalidSelection, e.message
          end
        end

        request = user.translation_requests.create!(
          client_request_key: client_request_key,
          source_text: source_text, source_language: source_language,
          target_language: target_language, preserve_formatting: preserve_formatting,
          use_glossary: use_glossary, glossary_snapshot: glossary_snapshot,
          submitted_at: Time.current, cost_acknowledged_at: Time.current, status: "queued",
          ui_locale: ui_locale.to_s.in?(%w[en vi]) ? ui_locale.to_s : "en"
        )
        model_ids.each do |id|
          model = models.fetch(id)
          deployment = model.active? ? model.active_deployment : nil
          connection = deployment&.inference_connection
          reason = if !model.active? then "MODEL_DISABLED"
                   elsif !deployment || !connection then "NOT_CONFIGURED"
                   elsif !connection.enabled? then "CONNECTION_DISABLED"
                   elsif connection.auth_type == "bearer" && !connection.token_configured? then "AUTHENTICATION_NOT_CONFIGURED"
                   end
          if reason.nil? && connection.adapter_key == "translation_gateway_v1"
            if source_text.length > source_limit_for_adapter(connection.adapter_key) then reason = "TEXT_TOO_LONG_FOR_GATEWAY"
            elsif ![source_language, target_language].all? { |s| s.match?(/\A[\p{Print}]{1,64}\z/) }
              reason = "INVALID_LANGUAGE_LABEL"
            end
          end
          if reason
            request.translation_runs.create!(translation_model: model, model_deployment: deployment,
              status: "failed", error_code: reason, attempt_no: 1, last_seen_at: Time.current)
            next
          end
          key = SecureRandom.uuid
          digest = Digest::SHA256.hexdigest([source_text, source_language, target_language,
            preserve_formatting, glossary_snapshot, model.model_key, deployment.id, deployment.remote_model_identifier].to_json)
          dispatch = request.translation_dispatches.create!(
            inference_connection: connection, provider_snapshot: connection.provider,
            adapter_key_snapshot: connection.adapter_key,
            base_url_snapshot: connection.base_url,
            remote_model_identifier_snapshot: deployment.remote_model_identifier,
            payload_digest: digest, idempotency_key: key, status: "pending"
          )
          request.translation_runs.create!(translation_model: model,
            translation_dispatch: dispatch, model_deployment: deployment,
            attempt_no: 1, status: "queued", last_seen_at: Time.current)
          dispatch_ids << dispatch.id
        end
        request.refresh_status! if dispatch_ids.empty?
        request
      end
      # Never enqueue before transaction commits; these tasks may lead to paid inference.
      dispatch_ids.each { |id| SubmitTranslationDispatchJob.perform_later(id) }
      record
    rescue ActiveRecord::RecordNotUnique
      validate_replayed_request!(user.translation_requests.find_by!(client_request_key: client_request_key),
        model_ids, source_text, source_language, target_language, preserve_formatting, use_glossary)
    end

    def self.validate_replayed_request!(request, model_ids, text, source, target, preserve, use_glossary)
      same = request.use_glossary == use_glossary && request.source_text == text && request.source_language == source &&
        request.target_language == target && request.preserve_formatting == preserve &&
        request.translation_runs.map(&:translation_model_id).uniq.sort == model_ids.sort
      raise InvalidSelection, I18n.t("errors.replayed_request") unless same
      request
    end
  end
end
