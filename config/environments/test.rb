Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  # Integration tests do not carry browser CSRF tokens; production CSRF remains enabled.
  config.action_controller.allow_forgery_protection = false
  # Non-secret test fixtures only; production encryption keys must come from the environment.
  config.active_record.encryption.primary_key ||= "test-primary-encryption-key-32-bytes!!"
  config.active_record.encryption.deterministic_key ||= "test-deterministic-key-32-bytes!!"
  config.active_record.encryption.key_derivation_salt ||= "test-derivation-salt-32-bytes!!!!!"
  config.active_job.queue_adapter = :test
  config.action_dispatch.show_exceptions = :rescuable
end
