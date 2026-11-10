module Admin
  module Settings
    class TranslationModelsController < Admin::BaseController
      before_action :require_recent_authentication!
      before_action :limit_settings_mutations!
      def limit_settings_mutations!
        throttle_admin_operation!(name: "settings", limit: 20, within: 10.minutes)
      end
      private :limit_settings_mutations!

      def update
        model = TranslationModel.find(params[:id])
        active = params[:active] == "1"
        changed = false
        model.with_lock do
          next if model.active? == active

          model.update!(active: active)
          InferenceSettingEvent.create!(user: current_user, translation_model: model,
            action: "model_#{active ? 'enabled' : 'disabled'}",
            changes_summary: { active: active, model_name: model.display_name, model_key: model.model_key })
          changed = true
        end
        redirect_to admin_settings_inference_path,
          notice: t(changed ? "notices.availability_updated" : "notices.availability_unchanged")
      end
    end
  end
end
