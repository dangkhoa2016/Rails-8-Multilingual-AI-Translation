# frozen_string_literal: true

require "uri"

module Translation
  # Fail fast when production lacks keys or uses the same database twice.
  # Error messages never contain credentials or complete connection strings.
  class ProductionConfiguration
    class Invalid < StandardError; end

    REQUIRED = %w[
      SECRET_KEY_BASE
      AR_ENCRYPTION_PRIMARY_KEY
      AR_ENCRYPTION_DETERMINISTIC_KEY
      AR_ENCRYPTION_KEY_DERIVATION_SALT
      DATABASE_URL QUEUE_DATABASE_URL CACHE_DATABASE_URL
    ].freeze

    MIN_LENGTH = {
      "SECRET_KEY_BASE" => 64,
      "AR_ENCRYPTION_PRIMARY_KEY" => 32,
      "AR_ENCRYPTION_DETERMINISTIC_KEY" => 32,
      "AR_ENCRYPTION_KEY_DERIVATION_SALT" => 32
    }.freeze

    def self.validate!(environment = ENV)
      missing = REQUIRED.select { |name| environment[name].to_s.strip.empty? }
      raise Invalid, "Missing production configuration: #{missing.join(', ')}" if missing.any?

      too_short = MIN_LENGTH.filter_map do |name, length|
        name if environment.fetch(name).to_s.length < length
      end
      raise Invalid, "Production keys are too short: #{too_short.join(', ')}" if too_short.any?

      encryption_keys = MIN_LENGTH.keys.filter_map do |name|
        environment.fetch(name).to_s if name.start_with?("AR_ENCRYPTION_")
      end
      unless encryption_keys.uniq.size == encryption_keys.size
        raise Invalid, "Production encryption keys must be distinct"
      end

      locations = %w[DATABASE_URL QUEUE_DATABASE_URL CACHE_DATABASE_URL].map do |name|
        parsed = begin
          URI.parse(environment.fetch(name))
        rescue URI::InvalidURIError
          nil
        end
        unless parsed && %w[postgres postgresql].include?(parsed.scheme) &&
               parsed.path.to_s.match?(%r{\A/[^/\s]+\z})
          raise Invalid, "Invalid PostgreSQL connection URL: #{name}"
        end
        [parsed.host.to_s.downcase, parsed.port, parsed.path]
      end
      unless locations.uniq.size == locations.size
        raise Invalid, "Primary, queue and cache must use distinct PostgreSQL databases"
      end
      true
    end
  end
end
