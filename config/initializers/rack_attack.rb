require "openssl"

# Rack::Attack blocks HTTP floods; LoginThrottle also applies a persistent,
# atomic PostgreSQL policy for every sign-in attempt.
Rack::Attack.cache.store = Rails.cache

Rack::Attack.throttled_responder = lambda do |_request|
  [429, {
    "Content-Type" => "text/plain; charset=utf-8",
    "Retry-After" => "300",
    "Cache-Control" => "no-store"
  }, ["Too many requests"]]
end

Rack::Attack.throttle("web/ip", limit: 240, period: 5.minutes) do |req|
  req.ip if req.get?
end

Rack::Attack.throttle("login/ip", limit: 20, period: 5.minutes) do |req|
  req.ip if req.post? && req.path == "/login"
end

Rack::Attack.throttle("login/identity+ip", limit: 10, period: 10.minutes) do |req|
  if req.post? && req.path == "/login"
    identity = req.params["email"].to_s.strip.downcase.byteslice(0, 254)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{req.ip}:#{identity}")
  end
rescue StandardError
  req.ip
end
