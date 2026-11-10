require "openssl"

class User < ApplicationRecord
  devise :database_authenticatable, :validatable
  has_many :translation_requests, dependent: :restrict_with_exception
  has_many :glossary_entries, dependent: :destroy
  has_many :inference_setting_events, dependent: :restrict_with_exception
  has_many :security_events, dependent: :restrict_with_exception
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :role, inclusion: { in: %w[admin] }

  def admin? = role == "admin"

  def session_fingerprint
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, encrypted_password)
  end
end
