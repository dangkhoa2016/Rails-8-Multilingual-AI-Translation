# Keep public registration disabled. Email recovery requires configured delivery.
Devise.setup do |config|
  require "devise/orm/active_record"
  config.mailer_sender = "no-reply@example.invalid"
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.password_length = 14..128
  # Idle and absolute expiry are enforced by SessionSecurity for HTTP and Action Cable.
  config.sign_out_via = :delete
  config.skip_session_storage = [:http_auth]
  config.paranoid = true
end
