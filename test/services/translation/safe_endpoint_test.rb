require "test_helper"

class SafeEndpointTest < ActiveSupport::TestCase
  test "rejects dangerous URL variants before network access" do
    invalid = ["http://example.com", "https://127.0.0.1", "https://localhost",
      "https://user:password@example.com", "https://example.com/?token=secret",
      "https://example.com:8080", "https://example.com/evil"]
    invalid.each do |url|
      assert_raises(Translation::SafeEndpoint::Invalid) { Translation::SafeEndpoint.parse!(url) }
    end
  end

  test "rejects private DNS and permits public HTTPS endpoints" do
    Resolv.stub(:getaddresses, ["169.254.169.254"]) do
      assert_raises(Translation::SafeEndpoint::Invalid) { Translation::SafeEndpoint.parse!("https://external.example") }
    end
    Resolv.stub(:getaddresses, ["8.8.8.8"]) do
      assert_equal "external.example", Translation::SafeEndpoint.parse!("https://external.example").host
    end
  end
end
