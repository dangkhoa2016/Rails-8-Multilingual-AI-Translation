require "test_helper"

class LoginThrottleTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "per identity and IP limit rejects sixth request without global account lockout" do
    5.times { assert LoginThrottle.allowed?(ip: "203.0.113.10", identity: "login:admin@example.com") }
    refute LoginThrottle.allowed?(ip: "203.0.113.10", identity: "login:admin@example.com")
    assert LoginThrottle.allowed?(ip: "203.0.113.11", identity: "login:admin@example.com")
  end

  test "per IP limit blocks attempts across identities" do
    12.times do |i|
      assert LoginThrottle.allowed?(ip: "203.0.113.20", identity: "login:#{i}@example.com")
    end
    refute LoginThrottle.allowed?(ip: "203.0.113.20", identity: "login:thirteenth@example.com")
  end

  test "counter expiration allows another attempt" do
    5.times { assert LoginThrottle.allowed?(ip: "203.0.113.30", identity: "login:admin@example.com") }
    refute LoginThrottle.allowed?(ip: "203.0.113.30", identity: "login:admin@example.com")
    travel 11.minutes do
      assert LoginThrottle.allowed?(ip: "203.0.113.30", identity: "login:admin@example.com")
    end
  end

  test "only HMAC keys not plaintext identities are stored" do
    LoginThrottle.allowed?(ip: "203.0.113.45", identity: "login:secret@example.com")
    keys = LoginThrottle.pluck(:key)
    assert keys.all? { |key| key.match?(/\A[0-9a-f]{64}\z/) }
    refute keys.any? { |key| key.include?("secret@example.com") || key.include?("203.0.113.45") }
  end
end
