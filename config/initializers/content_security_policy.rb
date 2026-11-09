Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    # Turbo inserts a fixed progress-bar <style> element on navigation.
    # Permit exactly this audited stylesheet by its SHA-256 CSP hash rather
    # than enabling unsafe-inline for arbitrary style injection.
    # Re-evaluate the hash when upgrading Turbo; browser acceptance checks CSP.
    policy.style_src :self, "'sha256-WAyOw4V+FqDc35lQPyRADLBWbuNK8ahvYEaQIYF1+Ps='"
    policy.connect_src :self
    policy.font_src :self, :data
    policy.img_src :self, :data
    policy.object_src :none
    policy.frame_ancestors :none
    policy.base_uri :self
    policy.form_action :self
  end

  # Turbo needs a stable CSP nonce across visits made in the same session.
  # Avoid unsafe-inline and allow importmap's inline <script type="importmap">.
  config.content_security_policy_nonce_generator = lambda do |request|
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  end
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_nonce_auto = true
end
