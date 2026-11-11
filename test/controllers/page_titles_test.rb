require "test_helper"

class PageTitlesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PRODUCT_TITLE = "Rails 8 Multilingual AI Translation"
  PASSWORD = "Example secure password 2026!"

  test "guest pages show localized browser titles" do
    get login_path
    assert_page_title "Administrator sign in"

    get "/missing-translation-page"
    assert_response :not_found
    assert_page_title "This page could not be found"

    patch preferences_path, params: { ui_locale: "vi", return_to: login_path }
    assert_redirected_to login_path

    get login_path
    assert_page_title "Đăng nhập quản trị"

    get "/trang-khong-ton-tai"
    assert_response :not_found
    assert_page_title "Trang này không tồn tại"
  end

  test "administrator pages use their own titles without invoking inference" do
    admin = create_administrator!
    sign_in_as!(admin)

    assert_no_enqueued_jobs do
      {
        new_admin_translation_path => "Translate and compare models",
        admin_translations_path => "Translation history",
        admin_settings_inference_path => "System Settings",
        admin_settings_inference_connections_path => "Inference connections",
        new_admin_settings_inference_connection_path => "New inference connection",
        admin_security_path => "Security Center"
      }.each do |path, title|
        get path
        assert_page_title title
      end

      patch preferences_path, params: { ui_locale: "vi", return_to: new_admin_translation_path }
      assert_redirected_to new_admin_translation_path
      get new_admin_translation_path
      assert_page_title "Dịch và so sánh các model"
      get admin_translations_path
      assert_page_title "Lịch sử dịch"
    end
  end

  test "translation detail title displays and escapes source and target labels" do
    admin = create_administrator!
    sign_in_as!(admin)
    translation = admin.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_text: "No remote inference needed",
      source_language: "English <example>",
      target_language: "Vietnamese",
      ui_locale: "en"
    )

    assert_no_enqueued_jobs do
      get admin_translation_path(translation)
      assert_page_title "English <example> → Vietnamese"
      assert_includes response.body, "English &lt;example&gt; → Vietnamese"
    end
  end

  private

  def assert_page_title(value)
    assert_response :success unless response.status == 404
    assert_select "head > title", text: "#{PRODUCT_TITLE} | #{value}", count: 1
  end

  def create_administrator!
    User.create!(
      email: "page-titles-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD,
      password_confirmation: PASSWORD,
      role: "admin"
    )
  end

  def sign_in_as!(admin)
    post login_path, params: { email: admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end
end
