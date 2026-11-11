require "test_helper"

class PreferencesTest < ActionDispatch::IntegrationTest
  test "locale may be selected by an anonymous user and persists" do
    patch preferences_path, params: { ui_locale: "vi", return_to: login_path }
    assert_redirected_to login_path
    get login_path
    assert_response :success
    assert_select 'html[lang="vi"]'
    assert_select "h1", text: /Đăng nhập quản trị/

    patch preferences_path, params: { ui_locale: "en", return_to: login_path }
    get login_path
    assert_select 'html[lang="en"]'
    assert_select "h1", text: /Administrator sign in/
  end

  test "light dark and auto themes persist in signed cookies" do
    %w[light dark auto].each do |theme|
      patch preferences_path, params: { ui_theme: theme, return_to: login_path }
      assert_redirected_to login_path
      get login_path
      assert_select %(html[data-theme="#{theme}"])
    end
  end

  test "Stimulus preference saves use JSON without redirects and update signed cookies" do
    patch preferences_path, params: { ui_theme: "dark", return_to: login_path }, as: :json
    assert_response :no_content
    assert_nil response.headers["Location"]
    get login_path
    assert_select 'html[data-theme="dark"]'

    patch preferences_path, params: { ui_locale: "vi", return_to: login_path }, as: :json
    assert_response :no_content
    assert_nil response.headers["Location"]
    get login_path
    assert_select 'html[lang="vi"]'
    assert_select "h1", text: /Đăng nhập quản trị/
  end

  test "layout renders SVG icons and Stimulus-controlled preference selectors" do
    get login_path
    assert_response :success
    assert_select 'form[data-controller="preference"]', count: 2
    assert_select 'form[data-turbo="false"]', count: 0
    assert_select 'svg[aria-hidden="true"]', minimum: 3
    assert_select 'select[data-action="change->preference#change"]', count: 2
  end

  test "system settings icon is distinct from the appearance theme icon" do
    password = "Strong password for settings icon test 2026!"
    admin = User.create!(
      email: "settings-icon-#{SecureRandom.hex(6)}@example.test",
      password: password, role: "admin"
    )
    post login_path, params: { email: admin.email, password: password }
    assert_redirected_to admin_translations_path

    %w[en vi].each do |locale|
      patch preferences_path, params: { ui_locale: locale, return_to: admin_dashboard_path }
      get admin_dashboard_path
      assert_response :success

      page = Nokogiri::HTML(response.body)
      settings_icon = page.at_css("a.app-nav-link[href='#{admin_settings_inference_path}'] svg")
      theme_control = page.at_css("select[name='ui_theme']")
      assert settings_icon, "Missing system settings navigation icon"
      assert theme_control, "Missing theme selection"
      theme_icon = theme_control.ancestors("form").first.at_css(".app-preference-icon svg")
      assert theme_icon, "Missing appearance icon"

      assert_equal 3, settings_icon.css("circle").size
      assert_equal 1, theme_icon.css("circle").size
      assert_not_equal settings_icon.to_html, theme_icon.to_html
      assert_includes settings_icon.at_css("path")["d"], "M3 6h7"
      assert_select "a.app-nav-link[href='#{admin_settings_inference_path}']",
        text: locale == "vi" ? /Cài đặt hệ thống/ : /System Settings/
    end
  end

  test "invalid settings are rejected and return path cannot redirect offsite" do
    patch preferences_path, params: { ui_theme: "script:evil", return_to: "//other-site.example/" }
    assert_response :unprocessable_entity
    patch preferences_path, params: { ui_locale: "fr", return_to: "//other-site.example/" }
    assert_response :unprocessable_entity
    patch preferences_path, params: { ui_locale: "vi", return_to: "//other-site.example/" }
    assert_redirected_to root_path
  end
end
