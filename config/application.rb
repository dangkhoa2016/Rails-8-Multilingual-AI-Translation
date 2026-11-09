require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module MultilingualTranslationWorkspace
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "UTC"
    config.i18n.available_locales = %i[en vi]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]
    config.active_job.queue_adapter = :solid_queue
    config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
    config.solid_queue.connects_to = { database: { writing: :queue } }
    config.generators.system_tests = nil
  end
end
