require "json"

module Translation
  # Retain only documented, non-credential API response fields. These snapshots
  # are not the original HTTP bytes or headers; never persist auth tokens or URLs.
  class ProviderResponseSnapshot
    MAX_BYTES = 32 * 1024
    JOB_FIELDS = %w[job_id kind status source_language target_language].freeze
    RUN_FIELDS = %w[run_id model attempt_no status translation_text is_mock_result error_code].freeze
    USAGE_FIELDS = %w[prompt_tokens completion_tokens total_tokens input_tokens output_tokens].freeze
    RESOURCE_FIELDS = %w[
      cpu_process_seconds cpu_utilization_percent sampled_vram_mib sampled_gpu_utilization_percent
    ].freeze
    TIMING_FIELDS = %w[
      total_ms inference_ms gpu_ms queue_ms prefill_ms decode_ms
      prompt_ms predicted_ms prompt_per_second predicted_per_second tokens_per_second
    ].freeze

    def self.gateway(payload:, run:)
      return unless payload.is_a?(Hash) && run.is_a?(Hash)

      safe_run = run.slice(*RUN_FIELDS)
      safe_run["usage"] = numeric_fields(run["usage"], USAGE_FIELDS) if run["usage"].is_a?(Hash)
      safe_run["timings"] = numeric_fields(run["timings"], TIMING_FIELDS) if run["timings"].is_a?(Hash)
      safe_run["resources"] = numeric_fields(run["resources"], RESOURCE_FIELDS) if run["resources"].is_a?(Hash)
      response = payload.slice(*JOB_FIELDS).merge("runs" => [safe_run])
      response["usage"] = numeric_fields(payload["usage"], USAGE_FIELDS) if payload["usage"].is_a?(Hash)
      response["timings"] = numeric_fields(payload["timings"], TIMING_FIELDS) if payload["timings"].is_a?(Hash)
      serialize(response)
    end

    def self.openai(payload:)
      return unless payload.is_a?(Hash)

      # Keep the returned text, model and usage, but never arbitrary provider
      # metadata, headers, request body, diagnostic dumps or authentication.
      response = payload.slice("id", "object", "model", "created")
      choices = Array(payload["choices"]).first(1).filter_map do |item|
        next unless item.is_a?(Hash)
        data = item.slice("index", "finish_reason")
        message = item["message"]
        data["message"] = message.slice("role", "content") if message.is_a?(Hash)
        data
      end
      response["choices"] = choices
      response["usage"] = numeric_fields(payload["usage"], USAGE_FIELDS) if payload["usage"].is_a?(Hash)
      response["timings"] = numeric_fields(payload["timings"], TIMING_FIELDS) if payload["timings"].is_a?(Hash)
      serialize(response)
    end

    def self.numeric_fields(values, allowed)
      values.slice(*allowed).select do |_, value|
        value.is_a?(Numeric) && value.finite? && value >= 0
      end
    end
    private_class_method :numeric_fields

    def self.serialize(value)
      json = JSON.generate(value)
      json if json.bytesize <= MAX_BYTES
    rescue JSON::GeneratorError, EncodingError, TypeError
      nil
    end
    private_class_method :serialize
  end
end
