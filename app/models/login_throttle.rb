require "openssl"

class LoginThrottle < ApplicationRecord
  self.primary_key = :key

  # Persistent, multi-process throttling. A compromised single IP cannot lock
  # an account globally: the narrower counter is bound to IP + identity.
  def self.allowed?(ip:, identity:)
    addr = ip.to_s.first(128)
    return false unless consume!("login_ip", addr, limit: 12, window: 5.minutes)
    consume!("login_identity_ip", "#{addr}:#{identity}", limit: 5, window: 10.minutes)
  end

  def self.reauthentication_allowed?(ip:, user_id:)
    consume!("reauth", "#{ip.to_s.first(128)}:#{user_id}", limit: 5, window: 10.minutes)
  end

  def self.consume!(scope, identifier, limit:, window:)
    key = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
      "translation-workspace:#{scope}:#{identifier}")
    now = Time.current
    item = create_or_find_by!(key: key) do |record|
      record.attempts = 0
      record.expires_at = now + window
    end
    allowed = false
    item.with_lock do
      if item.expires_at <= now
        item.update!(attempts: 1, expires_at: now + window)
        allowed = true
      else
        item.update!(attempts: item.attempts + 1)
        allowed = item.attempts <= limit
      end
    end
    allowed
  end
end
