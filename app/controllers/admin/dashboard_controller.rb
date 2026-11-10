module Admin
  class DashboardController < BaseController
    def index
      translations = current_user.translation_requests
      @total_translations = translations.count
      @status_counts = translations.group(:status).count
      @completed_runs = TranslationRun.joins(:translation_request)
        .where(translation_requests: { user_id: current_user.id }, status: "completed").count
      @needs_attention = @status_counts.values_at("failed", "partial_failed", "uncertain").compact.sum
      @in_progress = @status_counts.values_at("queued", "running").compact.sum
      @recent_translations = translations.order(created_at: :desc).limit(6)
      @models = TranslationModel.ordered.includes(model_deployments: :inference_connection).to_a
      @model_connections = @models.map do |model|
        deployment = model.model_deployments.find(&:active?)
        connection = deployment&.inference_connection
        ready = model.active? && deployment.present? && connection&.enabled? && connection&.token_configured?
        { model: model, connection: connection, ready: !!ready }
      end
      @ready_models = @model_connections.count { |item| item[:ready] }
    end
  end
end
