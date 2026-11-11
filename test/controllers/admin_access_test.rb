require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  test "anonymous cannot view settings or submit translations" do
    get admin_settings_inference_path
    assert_redirected_to login_path
    post admin_translations_path, params: { source_text: "hello" }
    assert_redirected_to login_path
  end
end
