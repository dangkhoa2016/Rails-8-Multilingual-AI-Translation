require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "A safe dashboard test password 2026!"

  test "dashboard requires administrator authentication" do
    get admin_dashboard_path
    assert_redirected_to login_path
  end

  test "dashboard presents real database counts without invoking inference" do
    user = create_admin!
    other = create_admin!
    model = TranslationModel.create!(
      model_key: "dashboard_#{SecureRandom.hex(4)}",
      display_name: "Dashboard test model", active: true
    )
    completed = create_translation!(user, status: "completed", source: "Private client document")
    failed = create_translation!(user, status: "failed", source: "Sensitive draft")
    create_translation!(other, status: "failed", source: "Another administrator's document")
    completed.translation_runs.create!(
      translation_model: model, status: "completed", attempt_no: 1,
      translation_text: "A translated sample"
    )
    sign_in_as!(user)

    assert_no_enqueued_jobs do
      get admin_dashboard_path
    end
    assert_response :success
    assert_select "head > title", text: "Rails 8 Multilingual AI Translation | Workspace overview"
    assert_select "a[href='#{admin_dashboard_path}']", minimum: 2
    assert_select "nav a[aria-current='page'][href='#{admin_dashboard_path}']", count: 1
    assert_select ".dashboard-metric", count: 4
    assert_select ".dashboard-metric-value", text: "2", count: 1
    assert_select ".dashboard-metric-value", text: "1", count: 2
    assert_select ".dashboard-activity-row[href='#{admin_translation_path(completed)}']", count: 1
    assert_select ".dashboard-activity-row[href='#{admin_translation_path(failed)}']", count: 1
    assert_select ".dashboard-activity-row", count: 2
    assert_not_includes response.body, "Private client document"
    assert_not_includes response.body, "Another administrator's document"
    assert_select ".dashboard-model-card", minimum: 1
    assert_select "button[data-action='click->workspace-nav#toggleMobile']", count: 1
    assert_select "button[data-action='click->workspace-nav#toggleCompact']", count: 1
  end

  test "dashboard has helpful empty state and localized Vietnamese copy" do
    sign_in_as!(create_admin!)

    get admin_dashboard_path
    assert_response :success
    assert_select ".dashboard-empty", count: 1
    assert_select ".dashboard-setup-notice", text: /No model is configured/
    assert_select "a[href='#{admin_settings_inference_path}']", minimum: 1

    patch preferences_path, params: { ui_locale: "vi", return_to: admin_dashboard_path }
    assert_redirected_to admin_dashboard_path
    get admin_dashboard_path
    assert_response :success
    assert_select 'html[lang="vi"]'
    assert_select "head > title", text: "Rails 8 Multilingual AI Translation | Tổng quan không gian làm việc"
    assert_select "h1", text: "Tổng quan không gian làm việc"
    assert_select ".dashboard-empty", text: /Không gian làm việc đã sẵn sàng/
  end

  test "login has product context without exposing protected dashboard" do
    get login_path
    assert_response :success
    assert_select ".auth-experience .app-auth-card", count: 1
    assert_select ".auth-experience .auth-story", count: 1
    assert_select ".auth-feature", count: 3
    assert_select "form[action='#{login_path}']", count: 1
    assert_select "a[href='#{admin_dashboard_path}']", count: 0
  end

  private

  def create_admin!
    User.create!(
      email: "dashboard-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
  end

  def sign_in_as!(user)
    post login_path, params: { email: user.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  def create_translation!(user, status:, source:)
    user.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_text: source,
      source_language: "en", target_language: "vi",
      status: status, ui_locale: "en"
    )
  end
end
