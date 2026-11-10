module Admin
  module Settings
    class InferenceController < Admin::BaseController
      def show
        @models = TranslationModel.ordered.includes(model_deployments: :inference_connection)
        @connections = InferenceConnection.order(:name)
        @events = InferenceSettingEvent.includes(:user, :translation_model, :inference_connection).order(created_at: :desc).limit(20)
      end
    end
  end
end
