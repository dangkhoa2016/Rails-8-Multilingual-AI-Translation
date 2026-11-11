require "test_helper"
require "bcrypt"

class SecurityCenterTest < ActionDispatch::IntegrationTest
  test "anonymous access is denied and successful sign-in is audited" do
    get admin_security_path
    assert_redirected_to login_path

    user = User.create!(email: "security-audit@example.test", password: "strong-password-2026", role: "admin")
    post login_path, params: { email: user.email, password: "strong-password-2026" }
    assert_redirected_to admin_translations_path
    assert_equal "login_success", SecurityEvent.where(user: user).last.event_type

    get admin_security_path
    assert_response :success
    assert_select "h1", /Security/i
  end

  test "Pundit rejects users without admin role" do
    outsider = User.new(email: "viewer@example.test", role: "viewer")
    refute AdminPolicy.new(outsider, :admin).access?
  end

  test "legacy BCrypt hash is supported after Devise column migration" do
    digest = BCrypt::Password.create("legacy-password-2026")
    user = User.create!(email: "legacy@example.test", role: "admin", password: "temporary-admin-password-2026")
    user.update_columns(encrypted_password: digest.to_s)
    post login_path, params: { email: user.email, password: "legacy-password-2026" }
    assert_redirected_to admin_translations_path
  end

  test "Rack Attack middleware and shared cache settings are registered" do
    assert Rails.application.middleware.any? { |middleware| middleware.klass == Rack::Attack }
    assert defined?(Rack::Attack.cache.store)
  end
end
