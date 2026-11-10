class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  protect_from_forgery with: :exception
  include Pundit::Authorization
  rescue_from ActionController::TooManyRequests, with: :render_rate_limit
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  RECENT_AUTH_TIMEOUT = 10.minutes

  helper_method :current_user, :ui_theme, :ui_locale
  around_action :switch_locale
  before_action :disable_sensitive_caching
  before_action :require_admin!

  private

  def ui_locale
    cookies.signed[:ui_locale].to_s.in?(%w[en vi]) ? cookies.signed[:ui_locale].to_s : "en"
  end

  def ui_theme
    cookies.signed[:ui_theme].to_s.in?(%w[light dark auto]) ? cookies.signed[:ui_theme].to_s : "auto"
  end

  def switch_locale(&action)
    I18n.with_locale(ui_locale.to_sym, &action)
  end

  def disable_sensitive_caching
    response.headers["Cache-Control"] = "no-store, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
  end

  def current_user
    return @current_user if defined?(@current_user)
    devise_user = warden.authenticate(scope: :user)
    @current_user = devise_user && SessionSecurity.user_from(session)
    @current_user = nil if @current_user && @current_user.id != devise_user.id
    if @current_user
      session[:last_seen_at] = Time.current.to_i
    elsif session[:user_id]
      reset_session
    end
    @current_user
  end

  def require_admin!
    return if current_user&.admin?
    redirect_to login_path, alert: t("auth.admin_required"), status: :see_other
  end

  def render_not_found
    return head :not_found unless request.format.html?

    render "errors/not_found", status: :not_found
  end

  def render_rate_limit
    response.headers["Retry-After"] ||= "60"
    flash.now[:alert] = t("auth.too_many_attempts")
    render "errors/rate_limited", status: :too_many_requests
  end

  def throttle_admin_operation!(name:, limit:, within:)
    return if LoginThrottle.consume!("admin:#{name}", current_user.id.to_s, limit: limit, window: within)
    response.headers["Retry-After"] = within.to_i.to_s
    raise ActionController::TooManyRequests
  end

  def require_recent_authentication!
    return if current_user&.admin? && session[:authenticated_at].to_i.positive? &&
      (Time.current.to_i - session[:authenticated_at].to_i).between?(0, RECENT_AUTH_TIMEOUT.to_i)
    redirect_to new_reauthentication_path, alert: t("auth.reauthentication_required"), status: :see_other
  end
end
