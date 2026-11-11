require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "anonymous pages use a strict CSP with only the audited Turbo stylesheet hash" do
    get login_path
    assert_response :success

    policy = response.headers.fetch("Content-Security-Policy")
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "style-src 'self' 'sha256-WAyOw4V+FqDc35lQPyRADLBWbuNK8ahvYEaQIYF1+Ps='"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "form-action 'self'"
    refute_includes policy, "'unsafe-inline'"
    refute_includes policy, "'unsafe-eval'"
    assert_includes response.headers.fetch("Cache-Control"), "no-store"
  end

  test "authenticated application keeps strict CSP, private caching and protected session cookies" do
    password = "Phase six CSP test password 2026!"
    admin = User.create!(
      email: "csp-admin-#{SecureRandom.hex(6)}@example.test",
      password: password, role: "admin"
    )
    post login_path, params: { email: admin.email, password: password }
    assert_redirected_to admin_translations_path
    cookies = response.headers.fetch("Set-Cookie")
    assert_match(/httponly/i, cookies)
    assert_match(/samesite=lax/i, cookies)

    %w[/admin/dashboard /admin/glossary_entries /admin/help].each do |path|
      get path
      assert_response :success
      policy = response.headers.fetch("Content-Security-Policy")
      assert_includes policy, "sha256-WAyOw4V+FqDc35lQPyRADLBWbuNK8ahvYEaQIYF1+Ps="
      refute_includes policy, "'unsafe-inline'"
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal "no-cache", response.headers.fetch("Pragma")
    end
  end
end
