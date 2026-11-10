class ReauthenticationsController < ApplicationController
  def new; end

  def create
    unless LoginThrottle.reauthentication_allowed?(ip: request.remote_ip, user_id: current_user.id)
      response.headers["Retry-After"] = "600"
      flash.now[:alert] = t("auth.too_many_attempts")
      return render :new, status: :too_many_requests
    end
    unless current_user.valid_password?(params[:password].to_s)
      flash.now[:alert] = t("auth.invalid_credentials")
      return render :new, status: :unprocessable_entity
    end

    user = current_user
    user_id, signed_in_at = user.id, session[:signed_in_at]
    sign_out(:user)
    reset_session
    sign_in(:user, user)
    session[:user_id] = user_id
    session[:signed_in_at] = signed_in_at
    session[:last_seen_at] = Time.current.to_i
    session[:authenticated_at] = Time.current.to_i
    session[:auth_fingerprint] = user.session_fingerprint
    SecurityEvent.record!(event_type: "reauthentication_success", user: user, ip: request.remote_ip)
    redirect_to admin_settings_inference_path, notice: t("auth.reauthenticated")
  end
end
