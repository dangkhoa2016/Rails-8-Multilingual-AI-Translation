module Admin
  class SecurityController < BaseController
    def index
      @admin_count = User.where(role: "admin").count
      @active_throttle_buckets = LoginThrottle.where("expires_at > ?", Time.current).count
      @security_events = SecurityEvent.includes(:user).order(created_at: :desc).limit(25)
      @setting_events = InferenceSettingEvent.includes(:user, :translation_model, :inference_connection).order(created_at: :desc).limit(15)
    end
  end
end
