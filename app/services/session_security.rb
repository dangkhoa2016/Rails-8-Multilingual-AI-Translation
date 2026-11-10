# Shared validation for controller sessions and Action Cable handshakes.
# User identity is never trusted from a cookie without verification of the
# cookie's encrypted signature, session time bounds and password fingerprint.
class SessionSecurity
  IDLE_TIMEOUT = 30.minutes
  ABSOLUTE_TIMEOUT = 12.hours

  def self.user_from(payload)
    return nil unless payload.respond_to?(:to_h)
    data = payload.to_h.with_indifferent_access
    user_id = data[:user_id]
    signed_in = data[:signed_in_at].to_i
    last_seen = data[:last_seen_at].to_i
    now = Time.current.to_i

    return nil if user_id.blank? || signed_in <= 0 || last_seen <= 0
    return nil if signed_in > now || last_seen > now
    return nil if now - signed_in > ABSOLUTE_TIMEOUT.to_i || now - last_seen > IDLE_TIMEOUT.to_i

    user = User.find_by(id: user_id)
    return nil unless user&.admin?
    fingerprint = data[:auth_fingerprint].to_s
    return nil unless fingerprint.bytesize == 64
    return nil unless ActiveSupport::SecurityUtils.secure_compare(fingerprint, user.session_fingerprint)
    user
  rescue TypeError, ArgumentError
    nil
  end
end
