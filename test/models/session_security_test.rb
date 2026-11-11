require "test_helper"

class SessionSecurityTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "verifies role session expiry and password fingerprint" do
    user = User.create!(email: "session-#{SecureRandom.hex(8)}@example.com",
      password: "A sufficiently long administrator passphrase", role: "admin")
    now = Time.current.to_i
    payload = { user_id: user.id, signed_in_at: now, last_seen_at: now,
      auth_fingerprint: user.session_fingerprint }
    assert_equal user, SessionSecurity.user_from(payload)
    assert_nil SessionSecurity.user_from(payload.merge(auth_fingerprint: "0" * 64))
    assert_nil SessionSecurity.user_from(payload.merge(last_seen_at: 31.minutes.ago.to_i))
    assert_nil SessionSecurity.user_from(payload.merge(signed_in_at: 13.hours.ago.to_i))
    user.update_column(:role, "viewer")
    assert_nil SessionSecurity.user_from(payload)
  end
end
