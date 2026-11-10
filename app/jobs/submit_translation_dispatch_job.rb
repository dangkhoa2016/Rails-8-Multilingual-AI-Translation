class SubmitTranslationDispatchJob < ApplicationJob
  queue_as :default

  def perform(id)
    dispatch = TranslationDispatch.find(id)
    # This transition is a one-way gate. If an interrupted POST has unknown outcome,
    # do not automatically put it back in pending or issue another paid request.
    dispatch.with_lock do
      return unless dispatch.status == "pending"
      dispatch.update!(status: "submitting", started_at: Time.current)
    end
    run = dispatch.translation_runs.first!
    request = dispatch.translation_request
    adapter = Translation::AdapterRouter.build(connection: dispatch.inference_connection,
      adapter_key: dispatch.adapter_key_snapshot, base_url: dispatch.base_url_snapshot)
    options = { preserve_formatting: request.preserve_formatting }
    if request.use_glossary?
      raise Translation::SafeEndpoint::Invalid, "Glossary unsupported by this adapter" unless dispatch.adapter_key_snapshot == "openai_chat_completions"
      options[:glossary] = JSON.parse(request.glossary_snapshot)
    end
    raw = adapter.submit(model_identifier: dispatch.remote_model_identifier_snapshot,
      source_language: request.source_language, target_language: request.target_language,
      text: request.source_text, options: options,
      idempotency_key: dispatch.idempotency_key)

    if adapter.asynchronous?
      remote_id = raw.fetch("job_id")
      raise Translation::HttpClient::NetworkError, "Invalid returned job_id" unless remote_id.match?(/\A[a-f0-9-]{36}\z/i)
      dispatch.update!(status: "accepted", remote_job_id: remote_id)
      run.update!(status: "running", last_seen_at: Time.current)
      PollTranslationDispatchJob.set(wait: 6.seconds).perform_later(dispatch.id)
    else
      run.update!(status: "completed", translation_text: raw.fetch("translation_text"),
        is_mock_result: raw.fetch("is_mock_result", false), last_seen_at: Time.current,
        provider_response_json: raw["provider_response_json"])
      dispatch.update!(status: "resolved", resolved_at: Time.current)
    end
    request.refresh_status!
  rescue Translation::HttpClient::HttpError => e
    # 5xx is ambiguous: the provider could have created a GPU job before responding.
    if e.status >= 500
      uncertain!(dispatch, "UPSTREAM_OUTCOME_UNKNOWN")
    else
      code = { 401 => "AUTHENTICATION_FAILED", 403 => "AUTHORIZATION_FAILED",
        429 => "RATE_LIMITED", 422 => "PROVIDER_REJECTED_INPUT" }.fetch(e.status, "UPSTREAM_REJECTED")
      failed!(dispatch, code)
    end
  rescue Translation::HttpClient::NetworkError, Translation::SafeEndpoint::Invalid, KeyError => e
    # Treat malformed/missing response as uncertain after submitting, never blind-retry.
    uncertain!(dispatch, "DISPATCH_OUTCOME_UNKNOWN")
  end

  private

  def failed!(dispatch, code)
    dispatch.update!(status: "failed", resolved_at: Time.current)
    dispatch.translation_runs.each { |run| run.update!(status: "failed", error_code: code, last_seen_at: Time.current) }
    dispatch.translation_request.refresh_status!
  end

  def uncertain!(dispatch, code)
    dispatch.update!(status: "uncertain")
    dispatch.translation_runs.each { |run| run.update!(status: "uncertain", error_code: code, last_seen_at: Time.current) }
    dispatch.translation_request.refresh_status!
  end
end
