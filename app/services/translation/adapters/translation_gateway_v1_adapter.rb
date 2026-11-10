module Translation
  module Adapters
    class TranslationGatewayV1Adapter < BaseAdapter
      def asynchronous? = true
      def connection_check = @client.get("/v1/models")

      def submit(model_identifier:, source_language:, target_language:, text:, options:, idempotency_key:)
        @client.post("/v1/jobs/translations", idempotency_key: idempotency_key, data: {
          model: model_identifier,
          source_language: source_language, target_language: target_language,
          text: text, options: options
        })
      end

      def fetch_status(remote_job_id:)
        raise SafeEndpoint::Invalid, "Invalid job identifier" unless remote_job_id.match?(/\A[a-f0-9-]{36}\z/i)
        @client.get("/v1/jobs/#{remote_job_id.downcase}")
      end
    end
  end
end
