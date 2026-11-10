module Translation
  class AdapterRouter
    ADAPTERS = {
      "translation_gateway_v1" => Adapters::TranslationGatewayV1Adapter,
      "openai_chat_completions" => Adapters::OpenaiChatCompletionsAdapter
    }.freeze

    def self.build(connection:, adapter_key: connection.adapter_key, base_url: nil)
      klass = ADAPTERS.fetch(adapter_key) { raise ArgumentError, "Unsupported API protocol" }
      klass.new(connection: connection, base_url: base_url)
    end
  end
end
