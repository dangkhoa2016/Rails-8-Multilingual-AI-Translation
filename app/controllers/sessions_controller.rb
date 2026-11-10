require "bcrypt"

class SessionsController < ApplicationController
  # The same SQL-backed throttle applies to every web process. Both dimensions
  # are keyed with HMAC; no user email or raw IP is stored in the limiter table.
  skip_before_action :require_admin!, only: %i[new create]

  DUMMY_DIGEST = BCrypt::Password.create(SecureRandom.hex(24)).to_s.freeze

  def new
    redirect_to root_path if current_user&.admin?
  end

  def create
    email = params[:email].to_s.strip.downcase.first(254)
    ip = request.remote_ip
    unless LoginThrottle.allowed?(ip: ip, identity: "login:#{email}")
      response.headers["Retry-After"] = "300"
      flash.now[:alert] = t("auth.too_many_attempts")
      return render :new, status: :too_many_requests
    end

    user = User.find_by(email: email)
    valid_password = if user&.admin?
      user.valid_password?(params[:password].to_s)
    else
      BCrypt::Password.new(DUMMY_DIGEST) == params[:password].to_s
      false
    end

    unless valid_password
      flash.now[:alert] = t("auth.invalid_credentials")
      return render :new, status: :unprocessable_entity
    end

    reset_session
    sign_in(:user, user)
    now = Time.current.to_i
    session[:user_id] = user.id
    session[:signed_in_at] = now
    session[:last_seen_at] = now
    session[:authenticated_at] = now
    session[:auth_fingerprint] = user.session_fingerprint
    SecurityEvent.record!(event_type: "login_success", user: user, ip: ip)
    redirect_to admin_translations_path, notice: t("auth.signed_in")
  end

  def destroy
    user = current_user
    SecurityEvent.record!(event_type: "logout", user: user, ip: request.remote_ip) if user
    sign_out(:user)
    reset_session
    redirect_to login_path, notice: t("auth.signed_out"), status: :see_other
  end
end
