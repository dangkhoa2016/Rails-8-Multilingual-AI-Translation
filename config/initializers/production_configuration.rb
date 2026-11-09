# frozen_string_literal: true

require_relative "../../lib/translation/production_configuration"

# Reject incomplete or unsafe production settings before serving requests.
# Development/test can still use disposable local PostgreSQL configurations.
Translation::ProductionConfiguration.validate! if Rails.env.production?
