module Admin
  module Settings
    class ModelDeploymentsController < Admin::BaseController
      before_action :require_recent_authentication!
      before_action :limit_settings_mutations!
      def limit_settings_mutations!
        throttle_admin_operation!(name: "settings", limit: 20, within: 10.minutes)
      end
      private :limit_settings_mutations!

      def create
        model = TranslationModel.find(params.require(:translation_model_id))
        connection = InferenceConnection.find(params.require(:inference_connection_id))
        unless connection.enabled? && connection.token_configured?
          return redirect_to admin_settings_inference_path, alert: t("notices.connection_must_be_ready")
        end
        identifier = params.require(:remote_model_identifier).to_s.strip
        return redirect_to admin_settings_inference_path, alert: t("notices.remote_identifier_required") if identifier.blank? || identifier.length > 120

        created = false
        model.with_lock do
          current = model.model_deployments.find_by(active: true)
          next if current&.inference_connection_id == connection.id &&
            current.remote_model_identifier == identifier

          model.model_deployments.where(active: true).update_all(active: false)
          deployment = model.model_deployments.create!(inference_connection: connection,
            remote_model_identifier: identifier, active: true,
            config_version: (model.model_deployments.maximum(:config_version) || 0) + 1)
          InferenceSettingEvent.create!(user: current_user, inference_connection: connection,
            translation_model: model, action: "deployment_activated",
            changes_summary: { config_version: deployment.config_version, provider: connection.provider,
              model_name: model.display_name, model_key: model.model_key,
              connection_name: connection.name, remote_model_identifier: identifier })
          created = true
        end
        redirect_to admin_settings_inference_path,
          notice: t(created ? "notices.deployment_updated" : "notices.deployment_unchanged")
      end
    end
  end
end
