require "test_helper"

class DispatchPlannerTest < ActiveJob::TestCase
  setup do
    @admin = User.create!(email: "admin@example.test", password: "safe-password-012345", role: "admin")
    @model = TranslationModel.find_or_create_by!(model_key: "hy_mt2_30b") do |model|
      model.display_name = "Hy-MT2"
    end
    @key = "11111111-1111-4111-8111-111111111111"
  end

  test "unconfigured model records an independent failure without queueing paid POST" do
    assert_no_enqueued_jobs do
      request = translate
      assert_equal "failed", request.status
      assert_equal "NOT_CONFIGURED", request.translation_runs.first.error_code
    end
  end

  test "same client key never schedules duplicate provider POST" do
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      conn = InferenceConnection.create!(name: "Gateway", provider: "modal", adapter_key: "translation_gateway_v1",
        base_url: "https://example.com", auth_type: "bearer", api_token: "dummy-test-value", enabled: true)
      ModelDeployment.create!(translation_model: @model, inference_connection: conn,
        remote_model_identifier: @model.model_key, active: true)
      assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
        first = translate
        second = translate
        assert_equal first.id, second.id
        assert_equal 1, first.translation_dispatches.count
      end
    end
  end

  test "an incompatible Gateway model prevents the entire mixed selection before any paid dispatch" do
    gateway_model = TranslationModel.create!(
      model_key: "gateway_length_#{SecureRandom.hex(4)}", display_name: "Gateway model", active: true
    )
    other_model = TranslationModel.create!(
      model_key: "openai_length_#{SecureRandom.hex(4)}", display_name: "Compatible API model", active: true
    )

    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      gateway = InferenceConnection.create!(
        name: "Gateway endpoint", provider: "other", adapter_key: "translation_gateway_v1",
        base_url: "https://example.com", auth_type: "bearer",
        api_token: "offline-gateway-token", enabled: true
      )
      openai = InferenceConnection.create!(
        name: "Compatible endpoint", provider: "other", adapter_key: "openai_chat_completions",
        base_url: "https://example.com", auth_type: "bearer",
        api_token: "offline-openai-token", enabled: true
      )
      ModelDeployment.create!(
        translation_model: gateway_model, inference_connection: gateway,
        remote_model_identifier: gateway_model.model_key, active: true
      )
      ModelDeployment.create!(
        translation_model: other_model, inference_connection: openai,
        remote_model_identifier: other_model.model_key, active: true
      )

      oversized = "a" * 5_000
      assert_no_enqueued_jobs do
        assert_no_difference ["TranslationRequest.count", "TranslationRun.count", "TranslationDispatch.count"] do
          error = assert_raises(Translation::DispatchPlanner::InvalidSelection) do
            Translation::DispatchPlanner.call(
              user: @admin, model_ids: [gateway_model.id, other_model.id],
              client_request_key: SecureRandom.uuid, source_text: oversized,
              source_language: "en", target_language: "vi", preserve_formatting: true,
              cost_approved: true
            )
          end
          assert_includes error.message, "Gateway model (1000)"
          assert_not_includes error.message, "Compatible API model"
        end
      end

      # An endpoint without a declared adapter limit is not arbitrarily restricted to 1,000.
      assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
        request = Translation::DispatchPlanner.call(
          user: @admin, model_ids: [other_model.id],
          client_request_key: SecureRandom.uuid, source_text: oversized,
          source_language: "en", target_language: "vi", preserve_formatting: true,
          cost_approved: true
        )
        assert_equal 1, request.translation_dispatches.count
        assert_equal "queued", request.translation_runs.first.status
      end
    end
  end

  test "the Gateway known input limit is inclusive and the application cap stays server enforced" do
    gateway_model = TranslationModel.create!(
      model_key: "gateway_boundary_#{SecureRandom.hex(4)}", display_name: "Boundary model", active: true
    )
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      connection = InferenceConnection.create!(
        name: "Boundary gateway", provider: "other", adapter_key: "translation_gateway_v1",
        base_url: "https://example.com", auth_type: "bearer",
        api_token: "offline-boundary-token", enabled: true
      )
      ModelDeployment.create!(
        translation_model: gateway_model, inference_connection: connection,
        remote_model_identifier: gateway_model.model_key, active: true
      )
      assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
        request = Translation::DispatchPlanner.call(
          user: @admin, model_ids: [gateway_model.id],
          client_request_key: SecureRandom.uuid, source_text: "x" * 1_000,
          source_language: "en", target_language: "vi", preserve_formatting: false,
          cost_approved: true
        )
        assert_equal "queued", request.translation_runs.first.status
      end

      assert_no_enqueued_jobs do
        assert_no_difference "TranslationRequest.count" do
          assert_raises(Translation::DispatchPlanner::InvalidSelection) do
            Translation::DispatchPlanner.call(
              user: @admin, model_ids: [gateway_model.id],
              client_request_key: SecureRandom.uuid, source_text: "x" * 1_001,
              source_language: "en", target_language: "vi", preserve_formatting: false,
              cost_approved: true
            )
          end
          error = assert_raises(Translation::DispatchPlanner::InvalidSelection) do
            Translation::DispatchPlanner.call(
              user: @admin, model_ids: [gateway_model.id],
              client_request_key: SecureRandom.uuid,
              source_text: "x" * (Translation::DispatchPlanner::MAX_SOURCE_CODEPOINTS + 1),
              source_language: "en", target_language: "vi", preserve_formatting: false,
              cost_approved: true
            )
          end
          assert_equal I18n.t("errors.input_limit"), error.message
        end
      end
    end
  end

  private

  def translate
    Translation::DispatchPlanner.call(user: @admin, model_ids: [@model.id], client_request_key: @key,
      source_language: "English", target_language: "Vietnamese", source_text: "Hello",
      preserve_formatting: true, cost_approved: true)
  end
end
