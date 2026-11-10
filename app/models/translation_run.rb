class TranslationRun < ApplicationRecord
  encrypts :translation_text, :provider_response_json
  after_update_commit :broadcast_progress_hint

  private

  def broadcast_progress_hint
    # The complete run card can exceed PostgreSQL NOTIFY's 8 KB payload limit.
    # Send a small change signal; the browser fetches the latest snapshot
    # through an authenticated, read-only Rails GET.
    broadcast_replace_to translation_request,
      target: "translation_signal_#{translation_request_id}",
      partial: "admin/translations/signal",
      locals: { translation: translation_request }
  end

  public
  belongs_to :translation_request
  belongs_to :translation_dispatch, optional: true
  belongs_to :translation_model
  belongs_to :model_deployment, optional: true
  validates :attempt_no, numericality: { greater_than: 0, only_integer: true }
  def terminal? = %w[completed failed uncertain].include?(status)
  def unsupported_language? = status == "failed" && error_code == "UNSUPPORTED_LANGUAGE_PAIR"

  def unchanged_output?
    status == "completed" && translation_text.present? &&
      translation_text == translation_request.source_text
  end

  def provider_response
    return unless provider_response_json.present?
    JSON.parse(provider_response_json)
  rescue JSON::ParserError
    nil
  end

  def provider_usage
    payload = provider_response
    return {} unless payload.is_a?(Hash)
    run_usage = payload.fetch("runs", []).first&.dig("usage") if payload["runs"].is_a?(Array)
    run_usage.is_a?(Hash) ? run_usage : payload["usage"].is_a?(Hash) ? payload["usage"] : {}
  end

  def provider_timings
    payload = provider_response
    return {} unless payload.is_a?(Hash)
    run_timings = payload.fetch("runs", []).first&.dig("timings") if payload["runs"].is_a?(Array)
    run_timings.is_a?(Hash) ? run_timings : payload["timings"].is_a?(Hash) ? payload["timings"] : {}
  end

  def provider_resources
    payload = provider_response
    return {} unless payload.is_a?(Hash)
    run_resources = payload.fetch("runs", []).first&.dig("resources") if payload["runs"].is_a?(Array)
    run_resources.is_a?(Hash) ? run_resources : {}
  end

  def dispatch_elapsed_seconds
    dispatch = translation_dispatch
    return unless dispatch&.started_at && dispatch&.resolved_at
    [(dispatch.resolved_at - dispatch.started_at).round(2), 0].max
  end

  def recorded_response
    {
      "run_id" => remote_run_id,
      "model" => translation_model.model_key,
      "attempt_no" => attempt_no,
      "status" => status,
      "translation_text" => translation_text,
      "is_mock_result" => is_mock_result,
      "error_code" => error_code
    }
  end
end
