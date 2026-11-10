require "openssl"

class SecurityEvent < ApplicationRecord
  belongs_to :user, optional: true

  EVENT_TYPES = %w[login_success logout reauthentication_success].freeze
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :ip_hash, length: { is: 64 }

  def self.record!(event_type:, user:, ip:)
    digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
      "security-event-ip:#{ip.to_s.byteslice(0, 128)}")
    create!(event_type: event_type, user: user, ip_hash: digest)
  end
end
