class InferenceConnection < ApplicationRecord
  URL_ERROR_CODES = {
    "HTTPS URL required" => "https_required",
    "Invalid hostname" => "invalid_host",
    "Standard HTTPS port 443 required" => "port",
    "Internal hostname is prohibited" => "internal_host",
    "Credentials, query and fragment are prohibited" => "credentials",
    "Base URL must not contain a path" => "path",
    "URL is too long" => "too_long",
    "Hostname could not be resolved" => "dns",
    "Endpoint resolves to a disallowed network" => "network",
    "Endpoint IP is not globally routable" => "public",
    "Malformed URL" => "malformed"
  }.freeze
  encrypts :api_token
  has_many :model_deployments, dependent: :restrict_with_exception
  has_many :translation_dispatches, dependent: :restrict_with_exception
  validates :name, presence: true
  validates :provider, inclusion: { in: %w[modal lightning runpod other] }
  validates :adapter_key, inclusion: { in: %w[translation_gateway_v1 openai_chat_completions] }
  validates :auth_type, inclusion: { in: %w[bearer] }
  validate :safe_base_url
  validate :credential_when_enabled
  before_validation :strip_token

  def token_configured? = api_token.present?

  private

  def strip_token
    self.api_token = api_token.strip if api_token.present?
  end

  def credential_when_enabled
    errors.add(:api_token, I18n.t("settings.token_required")) if enabled? && auth_type == "bearer" && !token_configured?
  end

  def safe_base_url
    Translation::SafeEndpoint.parse!(base_url)
  rescue Translation::SafeEndpoint::Invalid => e
    errors.add(:base_url, I18n.t("settings.url_errors.#{URL_ERROR_CODES.fetch(e.message, 'invalid')}"))
  end
end
