ENV["RAILS_ENV"] ||= "test"
ENV["AR_ENCRYPTION_PRIMARY_KEY"] ||= "test-primary-encryption-key-32-bytes!!"
ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"] ||= "test-deterministic-key-32-bytes!!"
ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "test-derivation-salt-32-bytes!!!!!"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"

class ActiveSupport::TestCase
  self.use_transactional_tests = true

  setup do
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end
end
