require "test_helper"

class NotFoundPagesTest < ActionDispatch::IntegrationTest
  PASSWORD = "A safe example password 2026!"

  test "a missing page shows branded public 404 instead of redirecting to sign in" do
    get "/this-page-does-not-exist"

    assert_response :not_found
    assert_select "main#app-main section.app-not-found", count: 1
    assert_select "h1#not-found-title", text: /could not be found/
    assert_select "a[href='#{login_path}']", text: /Sign in/, count: 1
    assert_select "a[href='#{admin_translations_path}']", count: 0
    assert_not_includes response.body, "ActionController::RoutingError"
  end

  test "public not found page follows the selected Vietnamese locale" do
    # Use the application's preference action so the signed cookie is valid.
    patch preferences_path, params: { ui_locale: "vi", return_to: login_path }
    assert_redirected_to login_path
    get "/duong-dan-khong-ton-tai"

    assert_response :not_found
    assert_select "h1#not-found-title", text: /không tồn tại/
    assert_select "a[href='#{login_path}']", text: /Đăng nhập/
  end

  test "an authenticated administrator sees navigation back to the workspace" do
    admin = User.create!(
      email: "not-found-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    post login_path, params: { email: admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path

    get "/admin/unknown-page"
    assert_response :not_found
    assert_select "main#app-main section.app-not-found", count: 1
    assert_select "section.app-not-found a[href='#{root_path}']", count: 1
    assert_select "section.app-not-found a[href='#{admin_translations_path}']", count: 1
    assert_select "a[href='#{login_path}']", count: 0
  end

  test "a missing translation record renders the same 404 without exposing private data" do
    admin = User.create!(
      email: "not-found-record-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    post login_path, params: { email: admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path

    get admin_translation_path(SecureRandom.uuid)
    assert_response :not_found
    assert_select "h1#not-found-title", text: /could not be found/
    assert_select "main#app-main section.app-not-found", count: 1
    assert_not_includes response.body, "ActiveRecord::RecordNotFound"
  end

  test "unmatched JSON requests return a minimal 404 without the HTML layout" do
    get "/unknown-service.json", headers: { "Accept" => "application/json" }

    assert_response :not_found
    assert_equal "", response.body
    assert_not_includes response.body, "Page not found"
  end

  test "unknown POST routes do not invoke inference and still return 404" do
    assert_no_difference("TranslationRequest.count") do
      post "/not-a-translation-endpoint", params: { source_text: "Do not run an inference" }
    end
    assert_response :not_found
    assert_select "h1#not-found-title", text: /could not be found/
  end
end
