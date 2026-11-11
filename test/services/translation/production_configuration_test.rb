require "test_helper"

class ProductionConfigurationTest < ActiveSupport::TestCase
  def good_environment
    {
      "SECRET_KEY_BASE" => "s" * 128,
      "AR_ENCRYPTION_PRIMARY_KEY" => "p" * 64,
      "AR_ENCRYPTION_DETERMINISTIC_KEY" => "d" * 64,
      "AR_ENCRYPTION_KEY_DERIVATION_SALT" => "z" * 64,
      "DATABASE_URL" => "postgresql://app:do-not-leak@database.example.com:5432/workspace",
      "QUEUE_DATABASE_URL" => "postgresql://app:do-not-leak@database.example.com:5432/workspace_queue",
      "CACHE_DATABASE_URL" => "postgresql://app:do-not-leak@database.example.com:5432/workspace_cache"
    }
  end

  test "accepts valid distinct PostgreSQL databases and independent keys" do
    assert_equal true, Translation::ProductionConfiguration.validate!(good_environment)
    socket_env = good_environment.merge(
      "DATABASE_URL" => "postgresql:///application",
      "QUEUE_DATABASE_URL" => "postgresql:///background_queue",
      "CACHE_DATABASE_URL" => "postgresql:///shared_cache"
    )
    assert_equal true, Translation::ProductionConfiguration.validate!(socket_env)
  end

  test "missing settings are rejected by field name without printing sensitive values" do
    values = good_environment.except("SECRET_KEY_BASE", "QUEUE_DATABASE_URL")
    error = assert_raises(Translation::ProductionConfiguration::Invalid) do
      Translation::ProductionConfiguration.validate!(values)
    end
    assert_includes error.message, "SECRET_KEY_BASE"
    assert_includes error.message, "QUEUE_DATABASE_URL"
    refute_includes error.message, "do-not-leak"
  end

  test "rejects short or duplicated encryption keys" do
    weak = good_environment.merge("SECRET_KEY_BASE" => "too-short")
    error = assert_raises(Translation::ProductionConfiguration::Invalid) do
      Translation::ProductionConfiguration.validate!(weak)
    end
    assert_includes error.message, "SECRET_KEY_BASE"

    duplicate = good_environment.merge(
      "AR_ENCRYPTION_DETERMINISTIC_KEY" => good_environment.fetch("AR_ENCRYPTION_PRIMARY_KEY")
    )
    assert_raises(Translation::ProductionConfiguration::Invalid) do
      Translation::ProductionConfiguration.validate!(duplicate)
    end
  end

  test "rejects missing database names, invalid schemes and identical database locations" do
    %w[https://db.example.com/app not-a-url postgresql://db.example.com/].each do |url|
      env = good_environment.merge("DATABASE_URL" => url)
      error = assert_raises(Translation::ProductionConfiguration::Invalid) do
        Translation::ProductionConfiguration.validate!(env)
      end
      assert_includes error.message, "DATABASE_URL"
    end

    duplicate = good_environment.merge(
      "QUEUE_DATABASE_URL" => "postgresql://another-user:another-secret@database.example.com:5432/workspace"
    )
    error = assert_raises(Translation::ProductionConfiguration::Invalid) do
      Translation::ProductionConfiguration.validate!(duplicate)
    end
    assert_includes error.message, "distinct PostgreSQL databases"
    refute_includes error.message, "another-secret"
  end

  test "logging filter hides privately submitted terms and snapshots" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    original = {
      "glossary_entry" => {
        "source_term" => "confidential-source-phrase",
        "target_term" => "confidential-target-phrase",
        "notes" => "private-note-secret"
      },
      "glossary_snapshot" => "encrypted-term-snapshot",
      "source_text" => "private-input-sentence",
      "client_request_key" => "uuid-secret-for-request",
      "provider_response_json" => "private-provider-body"
    }
    rendered = filter.filter(original).inspect
    %w[confidential-source-phrase confidential-target-phrase private-note-secret
      encrypted-term-snapshot private-input-sentence uuid-secret-for-request
      private-provider-body].each do |secret|
      refute_includes rendered, secret
    end
    assert_includes rendered, "[FILTERED]"
  end
end
