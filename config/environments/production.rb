Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.assume_ssl = true
  config.force_ssl = true
  config.log_level = :info
  config.active_support.report_deprecations = false
  config.action_controller.perform_caching = true
  config.cache_store = :solid_cache_store
  # Login throttles use PostgreSQL so limits are shared across web workers.
  # Keep the proxy IP trust configuration restricted to known proxies.
end
