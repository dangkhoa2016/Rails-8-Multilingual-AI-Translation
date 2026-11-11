require "test_helper"

class SessionsSecurityTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  PASSWORD = "A strong example password 2026!"

  def administrator
    @administrator ||= User.create!(email: "security-#{SecureRandom.hex(8)}@example.com",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin")
  end

  def sign_in
    post login_path, params: { email: administrator.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  test "login wrong email or password gives generic error" do
    post login_path, params: { email: "unknown-#{SecureRandom.hex(8)}@example.com", password: "bad" }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /Invalid email or password/
    post login_path, params: { email: administrator.email, password: "bad" }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", /Invalid email or password/
  end

  test "IP and identity login throttling returns HTTP 429" do
    email = administrator.email
    5.times do
      post login_path, params: { email: email, password: "bad" }
      assert_response :unprocessable_entity
    end
    post login_path, params: { email: email, password: "bad" }
    assert_response :too_many_requests
    assert_equal "300", response.headers["Retry-After"]
  end

  test "only admins may view settings" do
    sign_in
    get admin_settings_inference_path
    assert_response :success
    administrator.update_column(:role, "viewer")
    get admin_settings_inference_path
    assert_redirected_to login_path
  end

  test "expired idle session becomes unauthenticated" do
    sign_in
    travel 31.minutes do
      get admin_settings_inference_path
      assert_redirected_to login_path
    end
  end

  test "absolute session expires even with activity" do
    sign_in
    signed_in_at = Time.current
    # Maintain activity under the 30-minute idle timeout while advancing the absolute clock.
    (1..36).each do |step|
      travel_to(signed_in_at + step * 20.minutes) do
        get admin_settings_inference_path
        assert_response :success
      end
    end
    travel_to(signed_in_at + 12.hours + 1.minute) do
      get admin_settings_inference_path
      assert_redirected_to login_path
    end
  end

  test "password change invalidates prior session" do
    sign_in
    administrator.update!(password: "A different long password 2026!", password_confirmation: "A different long password 2026!")
    get admin_settings_inference_path
    assert_redirected_to login_path
  end

  test "sensitive write requires recent password reauthentication" do
    sign_in
    model = TranslationModel.create!(model_key: "security_#{SecureRandom.hex(5)}", display_name: "Security test")
    travel 11.minutes do
      patch admin_settings_translation_model_path(model), params: { active: "0" }
      assert_redirected_to new_reauthentication_path
      assert model.reload.active?
      post reauthentication_path, params: { password: PASSWORD }
      assert_redirected_to admin_settings_inference_path
      patch admin_settings_translation_model_path(model), params: { active: "0" }
      assert_redirected_to admin_settings_inference_path
      refute model.reload.active?
    end
  end

  test "settings mutation without login cannot bypass the policy" do
    model = TranslationModel.create!(model_key: "security_#{SecureRandom.hex(5)}", display_name: "Security test")
    patch admin_settings_translation_model_path(model), params: { active: "0" }
    assert_redirected_to login_path
    assert model.reload.active?
  end
end
