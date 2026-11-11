require "ostruct"
require "test_helper"

class GatewayAdapterTest < ActiveSupport::TestCase
  class RecordingClient
    attr_reader :path, :body, :key
    def post(path, data:, idempotency_key:)
      @path, @body, @key = path, data, idempotency_key
      { "job_id" => "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "status" => "queued" }
    end
    def get(path)
      @path = path
      { "models" => [] }
    end
  end

  test "one model uses Gateway v1 contract and carries a stable key" do
    fake = RecordingClient.new
    Translation::HttpClient.stub(:new, fake) do
      adapter = Translation::Adapters::TranslationGatewayV1Adapter.new(connection: OpenStruct.new(base_url: "https://example.org", api_token: "hidden"))
      result = adapter.submit(model_identifier: "hy_mt2_30b", source_language: "en", target_language: "vi",
        text: "Hello", options: { preserve_formatting: true }, idempotency_key: "fixed-key")
      assert_equal "/v1/jobs/translations", fake.path
      assert_equal "hy_mt2_30b", fake.body[:model]
      assert_equal "fixed-key", fake.key
      assert_equal "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", result["job_id"]
    end
  end
end
