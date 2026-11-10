class PollTranslationDispatchJob < ApplicationJob
  queue_as :default
  MAX_POLLS = 180
  ACTIVE = %w[queued dispatching running].freeze
  UNCERTAIN = %w[dispatch_uncertain execution_uncertain].freeze

  def perform(id)
    dispatch = TranslationDispatch.find(id)
    return unless dispatch.status == "accepted"

    adapter = Translation::AdapterRouter.build(connection: dispatch.inference_connection,
      adapter_key: dispatch.adapter_key_snapshot, base_url: dispatch.base_url_snapshot)
    payload = adapter.fetch_status(remote_job_id: dispatch.remote_job_id)
    remote_runs = Array(payload.fetch("runs")).select do |item|
      item.is_a?(Hash) && item["model"] == dispatch.remote_model_identifier_snapshot
    end
    raise Translation::HttpClient::NetworkError, "Expected model absent from remote job" if remote_runs.empty?

    latest_status = nil
    dispatch.with_lock do
      return unless dispatch.status == "accepted"
      remote_runs.sort_by { |item| Integer(item.fetch("attempt_no", 1)) }.each do |remote|
        attempt_no = Integer(remote.fetch("attempt_no", 1))
        unless attempt_no.between?(1, 10)
          raise Translation::HttpClient::NetworkError, "Invalid attempt number"
        end
        status = remote.fetch("status")
        unless (ACTIVE + UNCERTAIN + %w[completed failed]).include?(status)
          raise Translation::HttpClient::NetworkError, "Unknown provider status"
        end
        attributes = {
          status: ACTIVE.include?(status) ? "running" : (UNCERTAIN.include?(status) ? "uncertain" : status),
          remote_run_id: remote["run_id"],
          error_code: safe_error_code(remote["error_code"]),
          is_mock_result: remote.fetch("is_mock_result", false),
          last_seen_at: Time.current,
          provider_response_json: Translation::ProviderResponseSnapshot.gateway(payload: payload, run: remote)
        }
        if status == "completed"
          output = remote["translation_text"]
          raise Translation::HttpClient::NetworkError, "Completed response missing text" unless output.is_a?(String)
          attributes[:translation_text] = output
          attributes[:error_code] = nil
        end
        if status == "failed" && attributes[:error_code].blank?
          attributes[:error_code] = "UPSTREAM_FAILED"
        end
        run = dispatch.translation_runs.find_or_initialize_by(
          translation_model_id: dispatch.translation_runs.first!.translation_model_id,
          attempt_no: attempt_no
        )
        if run.new_record?
          previous = dispatch.translation_runs.first!
          run.translation_request = dispatch.translation_request
          run.model_deployment = previous.model_deployment
        end
        run.first_seen_at ||= Time.current
        run.update!(attributes)
        latest_status = status
      end
      attempts = dispatch.poll_attempts + 1
      next_status = if %w[completed failed].include?(latest_status)
        "resolved"
      elsif UNCERTAIN.include?(latest_status) || attempts >= MAX_POLLS
        "uncertain"
      else
        "accepted"
      end
      dispatch.update!(status: next_status, poll_attempts: attempts,
        last_polled_at: Time.current,
        resolved_at: next_status == "resolved" ? Time.current : nil)
      if next_status == "uncertain" && attempts >= MAX_POLLS
        dispatch.translation_runs.order(attempt_no: :desc).first!.update!(
          status: "uncertain", error_code: "POLLING_LIMIT_REACHED")
      end
    end
    dispatch.translation_request.refresh_status!
    PollTranslationDispatchJob.set(wait: 10.seconds).perform_later(dispatch.id) if dispatch.reload.status == "accepted"
  rescue Translation::HttpClient::HttpError => e
    # Safe read-only GET may be repeated. An auth error requires admin intervention.
    if [401, 403].include?(e.status)
      uncertain!(dispatch, "AUTHENTICATION_FAILED")
    else
      retry_safe_get!(dispatch)
    end
  rescue Translation::HttpClient::NetworkError, Translation::SafeEndpoint::Invalid, KeyError,
         ArgumentError, TypeError
    retry_safe_get!(dispatch)
  end

  private

  def safe_error_code(value)
    value.to_s.match?(/\A[A-Z][A-Z0-9_]{0,79}\z/) ? value : nil
  end

  def retry_safe_get!(dispatch)
    return unless dispatch.status == "accepted"
    attempts = dispatch.poll_attempts + 1
    if attempts >= MAX_POLLS
      uncertain!(dispatch, "STATUS_UNVERIFIED", attempts: attempts)
    else
      dispatch.update!(poll_attempts: attempts)
      PollTranslationDispatchJob.set(wait: 15.seconds).perform_later(dispatch.id)
    end
  end

  def uncertain!(dispatch, reason, attempts: nil)
    dispatch.update!(status: "uncertain", poll_attempts: attempts || dispatch.poll_attempts)
    dispatch.translation_runs.order(attempt_no: :desc).first!.update!(status: "uncertain", error_code: reason)
    dispatch.translation_request.refresh_status!
  end
end
