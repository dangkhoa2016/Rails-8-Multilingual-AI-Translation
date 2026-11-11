require "test_helper"

class ProviderResponseSnapshotTest < ActiveSupport::TestCase
  test "gateway snapshot keeps only contract fields and optional usage without credentials" do
    payload = {
      "job_id" => "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "kind" => "translation", "status" => "completed", "source_language" => "en",
      "target_language" => "vi", "authorization" => "SECRET-NOT-FOR-UI",
      "runs" => []
    }
    run = {
      "run_id" => "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      "model" => "hy_mt2_30b", "attempt_no" => 1, "status" => "completed",
      "translation_text" => "Xin chào", "is_mock_result" => false, "error_code" => nil,
      "api_token" => "SECRET-NOT-FOR-UI",
      "usage" => { "prompt_tokens" => 14, "completion_tokens" => 7,
        "total_tokens" => 21, "bearer" => "SECRET-NOT-FOR-UI" },
      "timings" => { "gpu_ms" => 182.25, "sensitive_diagnostics" => "SECRET-NOT-FOR-UI" },
      "resources" => { "sampled_vram_mib" => 32000, "sampled_gpu_utilization_percent" => 42,
        "cpu_process_seconds" => 2.9, "cpu_utilization_percent" => 380.0,
        "gpu_uuid" => "SECRET-NOT-FOR-UI", "gpu_memory_peak_mib" => 99999 }
    }

    captured = Translation::ProviderResponseSnapshot.gateway(payload: payload, run: run)
    snapshot = JSON.parse(captured)
    assert_equal "Xin chào", snapshot.dig("runs", 0, "translation_text")
    assert_equal 21, snapshot.dig("runs", 0, "usage", "total_tokens")
    assert_equal 182.25, snapshot.dig("runs", 0, "timings", "gpu_ms")
    assert_equal 32000, snapshot.dig("runs", 0, "resources", "sampled_vram_mib")
    assert_equal 380.0, snapshot.dig("runs", 0, "resources", "cpu_utilization_percent")
    assert_nil snapshot.dig("runs", 0, "resources", "gpu_memory_peak_mib")
    refute_includes captured, "SECRET-NOT-FOR-UI"
    assert_nil snapshot["authorization"]
    assert_nil snapshot.dig("runs", 0, "api_token")
  end

  test "OpenAI snapshot has usage when available but excludes arbitrary response metadata" do
    input = {
      "id" => "chatcmpl-test", "model" => "test-model", "secret" => "SECRET",
      "choices" => [
        { "index" => 0, "finish_reason" => "stop",
          "message" => { "role" => "assistant", "content" => "Translated", "internal" => "SECRET" } }
      ],
      "usage" => { "prompt_tokens" => 5, "completion_tokens" => 2, "total_tokens" => 7 }
    }
    snapshot = JSON.parse(Translation::ProviderResponseSnapshot.openai(payload: input))
    assert_equal "Translated", snapshot.dig("choices", 0, "message", "content")
    assert_equal 7, snapshot.dig("usage", "total_tokens")
    refute_includes JSON.generate(snapshot), "SECRET"
  end

  test "safe GET polling records an encrypted snapshot and usage without a GPU submission" do
    user = User.create!(email: "snapshot-#{SecureRandom.hex(4)}@example.test",
      password: "Safe example password 2026!", role: "admin")
    model = TranslationModel.create!(model_key: "snapshot_test_#{SecureRandom.hex(4)}", display_name: "Snapshot model")
    connection = nil
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      connection = InferenceConnection.create!(name: "Test API", provider: "other",
        adapter_key: "translation_gateway_v1", base_url: "https://example.com",
        auth_type: "bearer", api_token: "fake-token-for-offline-test", enabled: true)
    end
    request = user.translation_requests.create!(client_request_key: SecureRandom.uuid,
      source_text: "Hello", source_language: "en", target_language: "vi", ui_locale: "en")
    dispatch = request.translation_dispatches.create!(inference_connection: connection,
      provider_snapshot: "other", adapter_key_snapshot: "translation_gateway_v1",
      base_url_snapshot: "https://example.com", remote_model_identifier_snapshot: model.model_key,
      payload_digest: "digest", idempotency_key: SecureRandom.uuid,
      remote_job_id: SecureRandom.uuid, status: "accepted", started_at: 5.seconds.ago)
    run = request.translation_runs.create!(translation_model: model,
      translation_dispatch: dispatch, attempt_no: 1, status: "running")
    reply = { "job_id" => dispatch.remote_job_id, "kind" => "translation", "status" => "completed",
      "source_language" => "en", "target_language" => "vi",
      "runs" => [{ "run_id" => SecureRandom.uuid, "model" => model.model_key,
        "attempt_no" => 1, "status" => "completed", "translation_text" => "Xin chào",
        "is_mock_result" => false, "usage" => { "total_tokens" => 11 },
        "timings" => { "inference_ms" => 123.5 },
        "resources" => { "sampled_vram_mib" => 12345 },
        "api_token" => "SHOULD-NOT-BE-SAVED" }] }
    fake_adapter = Object.new
    fake_adapter.define_singleton_method(:fetch_status) { |remote_job_id:| reply }

    Translation::AdapterRouter.stub(:build, fake_adapter) do
      PollTranslationDispatchJob.perform_now(dispatch.id)
    end

    assert_equal "resolved", dispatch.reload.status
    assert_equal "completed", run.reload.status
    assert_equal "Xin chào", run.translation_text
    assert_equal 11, run.provider_usage["total_tokens"]
    assert_equal 123.5, run.provider_timings["inference_ms"]
    assert_equal 12345, run.provider_resources["sampled_vram_mib"]
    refute_includes run.provider_response_json, "SHOULD-NOT-BE-SAVED"
    raw_column = TranslationRun.connection.select_value(
      "SELECT provider_response_json FROM translation_runs WHERE id = #{TranslationRun.connection.quote(run.id)}"
    )
    refute_includes raw_column, "Xin chào"
    refute_includes raw_column, "SHOULD-NOT-BE-SAVED"
  end

  test "oversized response is omitted rather than stored or crashing" do
    result = Translation::ProviderResponseSnapshot.gateway(
      payload: { "status" => "completed" },
      run: { "translation_text" => "A" * (Translation::ProviderResponseSnapshot::MAX_BYTES + 1) }
    )
    assert_nil result
  end
end
