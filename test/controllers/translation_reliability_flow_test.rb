require "test_helper"

class TranslationReliabilityFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "Offline-phase-five-test-passphrase-2026"

  # Complete in-process HTTP boundary: adapters, controller, database, and jobs
  # are real; no sockets, GPUs or paid requests are ever contacted.
  class MockTranslationProvider
    attr_reader :post_calls, :get_calls, :post_errors, :poll_status

    def initialize
      @post_calls, @get_calls = [], []
      @post_errors, @poll_status = {}, {}
      @remote_models = {}
    end

    def post(path, idempotency_key:, data:)
      model = data.fetch(:model)
      @post_calls << { path: path, key: idempotency_key, model: model, data: data }
      raise @post_errors.fetch(model) if @post_errors.key?(model)

      case path
      when "/v1/jobs/translations"
        id = SecureRandom.uuid
        @remote_models[id] = model
        { "job_id" => id, "status" => "queued" }
      when "/v1/chat/completions"
        { "choices" => [{ "message" => { "content" => "Translated #{model}" } }],
          "usage" => { "total_tokens" => 14 },
          "provider_secret" => "NOT-FOR-DATABASE" }
      else
        raise "Unexpected POST path: #{path}"
      end
    end

    def get(path)
      @get_calls << path
      id = path.delete_prefix("/v1/jobs/")
      model = @remote_models.fetch(id)
      response_status = @poll_status.fetch(model, "completed")
      raise response_status if response_status.is_a?(Exception)

      { "job_id" => id, "kind" => "translation", "status" => response_status,
        "runs" => [{
          "run_id" => SecureRandom.uuid,
          "model" => model, "attempt_no" => 1,
          "status" => response_status,
          "translation_text" => response_status == "completed" ? "Translated #{model}" : nil,
          "is_mock_result" => true,
          "usage" => { "total_tokens" => 11 },
          "provider_secret" => "NOT-FOR-DATABASE"
        }] }
    end
  end

  setup do
    @admin = User.create!(
      email: "flow-admin-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD, role: "admin"
    )
    @provider = MockTranslationProvider.new
    post login_path, params: { email: @admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  test "four-model controller-to-adapter-to-poll-to-history-to-export flow and replay safety" do
    gateway_a = attach_model("gateway_a", "translation_gateway_v1")
    openai_a = attach_model("openai_a", "openai_chat_completions")
    gateway_b = attach_model("gateway_b", "translation_gateway_v1")
    openai_b = attach_model("openai_b", "openai_chat_completions")
    models = [gateway_a, openai_a, gateway_b, openai_b]
    client_key = SecureRandom.uuid

    Translation::HttpClient.stub(:new, @provider) do
      assert_difference({
        "TranslationRequest.count" => 1,
        "TranslationDispatch.count" => 4,
        "TranslationRun.count" => 4
      }) do
        perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
          post admin_translations_path, params: translation_params(models, client_key)
          assert_response :redirect
        end
      end
      request = @admin.translation_requests.find_by!(client_request_key: client_key)
      assert_equal "running", request.reload.status
      assert_equal 4, @provider.post_calls.length
      assert_equal 4, @provider.post_calls.map { |call| call.fetch(:key) }.uniq.length
      assert_equal 2, request.translation_dispatches.where(status: "accepted").count
      assert_equal 2, request.translation_dispatches.where(status: "resolved").count

      gateway_dispatches = request.translation_dispatches.where(status: "accepted").order(:id).to_a
      gateway_dispatches.each do |dispatch|
        PollTranslationDispatchJob.perform_now(dispatch.id)
      end
      assert_equal "completed", request.reload.status
      assert request.translation_runs.all? { |run| run.status == "completed" }
      assert_equal 2, @provider.get_calls.length
      assert_equal 4, @provider.post_calls.length

      assert_no_enqueued_jobs do
        post admin_translations_path, params: translation_params(models, client_key)
      end
      assert_response :redirect
      assert_equal 1, @admin.translation_requests.where(client_request_key: client_key).count
      assert_equal 4, @provider.post_calls.length
      assert_equal 4, request.translation_dispatches.count
      SubmitTranslationDispatchJob.perform_now(request.translation_dispatches.first.id)
      assert_equal 4, @provider.post_calls.length

      get admin_translation_path(request)
      assert_response :success
      assert_select "article[data-translation-compare-completed='true']", count: 4
      get admin_translations_path(status: "completed")
      assert_response :success
      assert_select "a.history-record[href='#{admin_translation_path(request)}']", count: 1
      get export_admin_translation_path(request, file_format: "json")
      assert_response :success
      json = JSON.parse(response.body)
      assert_equal 4, json.fetch("results").count
      assert_equal "Hello phase five", json.dig("session", "source_text")
      assert_not_includes response.body, "NOT-FOR-DATABASE"
      assert_not_includes response.body, "offline-test-token"
    end
  end

  test "provider 422 failure stays isolated, completed sibling succeeds, and no POST is replayed" do
    completed = attach_model("completed", "openai_chat_completions")
    rejected = attach_model("rejected", "openai_chat_completions")
    @provider.post_errors[rejected.model_key] = Translation::HttpClient::HttpError.new(422)
    Translation::HttpClient.stub(:new, @provider) do
      perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
        post admin_translations_path, params: translation_params([completed, rejected], SecureRandom.uuid)
        assert_response :redirect
      end
      request = @admin.translation_requests.order(created_at: :desc).first!
      assert_equal "partial_failed", request.reload.status
      assert_equal ["completed", "failed"], request.translation_runs.order(:status).map(&:status)
      failed = request.translation_runs.find_by!(status: "failed")
      assert_equal "PROVIDER_REJECTED_INPUT", failed.error_code
      assert_equal 2, @provider.post_calls.count
      SubmitTranslationDispatchJob.perform_now(failed.translation_dispatch_id)
      assert_equal 2, @provider.post_calls.count
    end
  end

  test "provider 503 or network uncertainty never causes a second paid POST" do
    %w[http_503 network_timeout].each do |case_name|
      model = attach_model("uncertain_#{case_name}", "openai_chat_completions")
      @provider.post_errors[model.model_key] =
        case_name == "http_503" ? Translation::HttpClient::HttpError.new(503) :
          Translation::HttpClient::NetworkError.new("simulated timeout")
      Translation::HttpClient.stub(:new, @provider) do
        count_before = @provider.post_calls.length
        perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
          post admin_translations_path, params: translation_params([model], SecureRandom.uuid)
          assert_response :redirect
        end
        request = @admin.translation_requests.order(created_at: :desc).first!
        dispatch = request.translation_dispatches.first!
        assert_equal "uncertain", dispatch.status
        assert_equal "uncertain", request.reload.status
        assert_equal "uncertain", request.translation_runs.first.status
        assert_equal "UPSTREAM_OUTCOME_UNKNOWN", request.translation_runs.first.error_code if case_name == "http_503"
        assert_equal count_before + 1, @provider.post_calls.length
        SubmitTranslationDispatchJob.perform_now(dispatch.id)
        ReconcileTranslationDispatchesJob.perform_now
        assert_equal count_before + 1, @provider.post_calls.length
      end
    end
  end

  test "post-crash submitting state becomes uncertain without any replay" do
    model = attach_model("crashed", "translation_gateway_v1")
    assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
      post admin_translations_path, params: translation_params([model], SecureRandom.uuid)
      assert_response :redirect
    end
    request = @admin.translation_requests.last!
    dispatch = request.translation_dispatches.first!
    dispatch.update!(status: "submitting", started_at: 30.minutes.ago)
    assert_equal "queued", request.translation_runs.first.status

    assert_no_enqueued_jobs(only: SubmitTranslationDispatchJob) do
      ReconcileTranslationDispatchesJob.perform_now
      ReconcileTranslationDispatchesJob.perform_now
      SubmitTranslationDispatchJob.perform_now(dispatch.id)
    end
    assert_equal "uncertain", dispatch.reload.status
    assert_equal "uncertain", request.reload.status
    assert_equal "DISPATCH_OUTCOME_UNKNOWN", request.translation_runs.first.reload.error_code
    assert_empty @provider.post_calls
  end

  test "stale accepted poll is recovered by GET only; repeated reconciliation never submits" do
    model = attach_model("stale_poll", "translation_gateway_v1")
    Translation::HttpClient.stub(:new, @provider) do
      perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
        post admin_translations_path, params: translation_params([model], SecureRandom.uuid)
        assert_response :redirect
      end
      request = @admin.translation_requests.last!
      dispatch = request.translation_dispatches.first!
      assert_equal "accepted", dispatch.status
      assert_equal 1, @provider.post_calls.length
      clear_enqueued_jobs

      dispatch.update_columns(updated_at: 30.minutes.ago, last_polled_at: 30.minutes.ago)
      # GET can wake sleeping inference hosting. Without explicit opt-in, the
      # reconciler must not contact or schedule an external status request.
      assert_no_enqueued_jobs(only: PollTranslationDispatchJob) do
        ReconcileTranslationDispatchesJob.perform_now
      end
      with_recovery_polling_enabled do
        assert_enqueued_jobs 1, only: PollTranslationDispatchJob do
          ReconcileTranslationDispatchesJob.perform_now
        end
      end
      assert_equal 1, @provider.post_calls.length
      PollTranslationDispatchJob.perform_now(dispatch.id)
      clear_enqueued_jobs
      assert_equal "completed", request.reload.status
      assert_equal "resolved", dispatch.reload.status
      assert_equal 1, @provider.post_calls.length
      assert_equal 1, @provider.get_calls.length

      assert_no_enqueued_jobs(only: PollTranslationDispatchJob) do
        ReconcileTranslationDispatchesJob.perform_now
      end
    end
  end

  test "safe GET failure schedules polling retry, but no additional POST" do
    model = attach_model("get_timeout", "translation_gateway_v1")
    @provider.poll_status[model.model_key] = Translation::HttpClient::NetworkError.new("GET timeout")
    Translation::HttpClient.stub(:new, @provider) do
      perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
        post admin_translations_path, params: translation_params([model], SecureRandom.uuid)
      end
      request = @admin.translation_requests.last!
      dispatch = request.translation_dispatches.first!
      clear_enqueued_jobs
      assert_enqueued_jobs 1, only: PollTranslationDispatchJob do
        PollTranslationDispatchJob.perform_now(dispatch.id)
      end
      assert_equal "accepted", dispatch.reload.status
      assert_equal 1, dispatch.poll_attempts
      assert_equal 1, @provider.post_calls.length
      assert_equal 1, @provider.get_calls.length
      assert_equal "running", request.reload.status
    end
  end

  test "recurring recovery is configured for development and production, not tests" do
    config = YAML.safe_load_file(Rails.root.join("config/recurring.yml"))
    %w[development production].each do |env|
      definition = config.fetch(env).fetch("reconcile_translation_dispatches")
      assert_equal "ReconcileTranslationDispatchesJob", definition.fetch("class")
      assert_equal "every 5 minutes", definition.fetch("schedule")
    end
    refute config.key?("test")
  end

  test "opt-in glossary is snapshotted and reaches the OpenAI adapter without extra POSTs" do
    model = attach_model("glossary", "openai_chat_completions")
    entry = @admin.glossary_entries.create!(
      source_language: "en", target_language: "vi",
      source_term: "apprenticeship", target_term: "học nghề",
      notes: "private note must remain local", active: true
    )
    key = SecureRandom.uuid

    Translation::HttpClient.stub(:new, @provider) do
      perform_enqueued_jobs(only: SubmitTranslationDispatchJob) do
        post admin_translations_path, params: translation_params([model], key).merge(
          source_text: "apprenticeship opportunities", use_glossary: "1"
        )
        assert_response :redirect
      end
      request = @admin.translation_requests.find_by!(client_request_key: key)
      assert request.use_glossary?
      assert_equal "completed", request.reload.status
      assert_equal 1, @provider.post_calls.count
      prompt = @provider.post_calls.first.dig(:data, :messages, 0, :content)
      assert_includes prompt, "học nghề"
      refute_includes prompt, "private note"
      assert_equal [{ "source" => "apprenticeship", "target" => "học nghề" }], request.glossary_terms

      entry.update!(target_term: "việc học nghề")
      assert_equal "học nghề", request.reload.glossary_terms.first.fetch("target")
      assert_no_enqueued_jobs do
        post admin_translations_path, params: translation_params([model], key).merge(
          source_text: "apprenticeship opportunities", use_glossary: "1"
        )
      end
      assert_equal 1, @provider.post_calls.count
      get admin_translation_path(request)
      assert_response :success
      assert_select ".glossary-used-note", text: /1 matching terms/
      get export_admin_translation_path(request, file_format: "json")
      assert_response :success
      assert_equal true, JSON.parse(response.body).dig("session", "use_glossary")
      refute_includes response.body, "private note"
    end
  end

  private

  def with_recovery_polling_enabled
    previous = ENV["TRANSLATION_RECOVERY_POLLING_ENABLED"]
    ENV["TRANSLATION_RECOVERY_POLLING_ENABLED"] = "1"
    yield
  ensure
    ENV["TRANSLATION_RECOVERY_POLLING_ENABLED"] = previous
  end

  def attach_model(label, adapter_key)
    model = TranslationModel.create!(
      model_key: "flow_#{label}_#{SecureRandom.hex(3)}",
      display_name: "Flow #{label}", active: true
    )
    connection = nil
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      connection = InferenceConnection.create!(
        name: "Offline #{label}", provider: "other", adapter_key: adapter_key,
        base_url: "https://example.com", auth_type: "bearer",
        api_token: "offline-test-token", enabled: true
      )
    end
    ModelDeployment.create!(
      translation_model: model, inference_connection: connection,
      remote_model_identifier: model.model_key, active: true
    )
    model
  end

  def translation_params(models, key)
    {
      source_text: "Hello phase five", source_language: "en", target_language: "vi",
      model_ids: models.map(&:id), client_request_key: key,
      cost_approved: "1", preserve_formatting: "1"
    }
  end
end
