require "test_helper"

class GlossaryWorkflowTest < ActiveJob::TestCase
  setup do
    @admin = User.create!(
      email: "glossary-planner-#{SecureRandom.hex(5)}@example.test",
      password: "Long safe glossary test password 2026!", role: "admin"
    )
    @model = TranslationModel.create!(
      model_key: "glossary_model_#{SecureRandom.hex(5)}",
      display_name: "Glossary test model", active: true
    )
    @key = SecureRandom.uuid
  end

  test "opt-in snapshots matching terms, persists encrypted content, and never replays a paid request" do
    term = @admin.glossary_entries.create!(
      source_language: "English", target_language: "Vietnamese",
      source_term: "apprenticeship", target_term: "học nghề",
      notes: "private note, must never reach provider", active: true
    )
    @admin.glossary_entries.create!(
      source_language: "English", target_language: "Vietnamese",
      source_term: "NOT IN INPUT", target_term: "should not apply", active: true
    )
    connection = create_connection("openai_chat_completions")
    deploy(@model, connection)

    assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
      request = translate(model_ids: [@model.id], use_glossary: true)
      assert_equal true, request.use_glossary?
      assert_equal 1, request.translation_dispatches.count
      snapshot = JSON.parse(request.glossary_snapshot)
      assert_equal [{ "source" => "apprenticeship", "target" => "học nghề" }], snapshot
      assert_not_includes request.glossary_snapshot, "private note"
      raw = TranslationRequest.connection.select_value(
        TranslationRequest.sanitize_sql_array(["SELECT glossary_snapshot FROM translation_requests WHERE id = ?", request.id])
      )
      refute_includes raw, "apprenticeship"

      term.update!(target_term: "việc học nghề")
      replay = translate(model_ids: [@model.id], use_glossary: true)
      assert_equal request.id, replay.id
      assert_equal snapshot, JSON.parse(replay.glossary_snapshot)

      err = assert_raises(Translation::DispatchPlanner::InvalidSelection) do
        translate(model_ids: [@model.id], use_glossary: false)
      end
      assert_includes err.message, I18n.t("errors.replayed_request")
    end
  end

  test "Gateway v1 with selected glossary is rejected before storing or enqueueing" do
    @admin.glossary_entries.create!(
      source_language: "English", target_language: "Vietnamese",
      source_term: "apprenticeship", target_term: "học nghề"
    )
    connection = create_connection("translation_gateway_v1")
    deploy(@model, connection)
    assert_no_enqueued_jobs do
      assert_no_difference ["TranslationRequest.count", "TranslationDispatch.count"] do
        error = assert_raises(Translation::DispatchPlanner::InvalidSelection) do
          translate(model_ids: [@model.id], use_glossary: true)
        end
        assert_includes error.message, "Glossary test model"
      end
    end
  end

  test "Glossary rejects missing terms without paid jobs, but normal translation stays unchanged" do
    connection = create_connection("openai_chat_completions")
    deploy(@model, connection)
    assert_no_enqueued_jobs do
      assert_no_difference "TranslationRequest.count" do
        error = assert_raises(Translation::DispatchPlanner::InvalidSelection) do
          translate(model_ids: [@model.id], use_glossary: true)
        end
        assert_equal I18n.t("errors.glossary_no_matches"), error.message
      end
    end

    assert_enqueued_jobs 1, only: SubmitTranslationDispatchJob do
      request = translate(model_ids: [@model.id], use_glossary: false)
      assert_not request.use_glossary?
      assert_nil request.glossary_snapshot
    end
  end

  test "only active terms in this account and language pair are included" do
    @admin.glossary_entries.create!(
      source_language: "english", target_language: "vietnamese",
      source_term: "APPRENTICESHIP", target_term: "học nghề"
    )
    @admin.glossary_entries.create!(
      source_language: "English", target_language: "Vietnamese",
      source_term: "apprenticeship", target_term: "disabled", active: false
    )
    another = User.create!(
      email: "another-glossary-#{SecureRandom.hex(5)}@example.test",
      password: "Another long test password 2026!", role: "admin"
    )
    another.glossary_entries.create!(
      source_language: "English", target_language: "Vietnamese",
      source_term: "apprenticeship", target_term: "FOREIGN TRANSLATION"
    )
    snapshot = Translation::GlossarySnapshot.build(
      user: @admin, source_language: "English", target_language: "Vietnamese",
      source_text: "apprenticeship is useful"
    )
    parsed = JSON.parse(snapshot)
    assert_equal 1, parsed.size
    assert_equal "học nghề", parsed.first["target"]
    assert_not_includes snapshot, "FOREIGN"
  end

  test "glossary term count bound blocks costly oversized prompts before dispatch" do
    21.times do |n|
      @admin.glossary_entries.create!(
        source_language: "English", target_language: "Vietnamese",
        source_term: "token#{n}", target_term: "term#{n}"
      )
    end
    connection = create_connection("openai_chat_completions")
    deploy(@model, connection)
    assert_no_enqueued_jobs do
      assert_no_difference "TranslationRequest.count" do
        assert_raises(Translation::DispatchPlanner::InvalidSelection) do
          Translation::DispatchPlanner.call(
            user: @admin, source_text: (0..20).map { |n| "token#{n}" }.join(" "),
            source_language: "English", target_language: "Vietnamese",
            model_ids: [@model.id], preserve_formatting: true, client_request_key: @key,
            cost_approved: true, use_glossary: true
          )
        end
      end
    end
  end

  test "OpenAI adapter includes reference term pairs in system message without private notes" do
    captured = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:post) do |path, idempotency_key:, data:|
      captured = [path, idempotency_key, data]
      { "choices" => [{ "message" => { "content" => "học nghề" } }] }
    end
    adapter = Translation::Adapters::OpenaiChatCompletionsAdapter.allocate
    adapter.instance_variable_set(:@client, fake_client)
    result = adapter.submit(model_identifier: "mock-test-model", source_language: "English",
      target_language: "Vietnamese", text: "apprenticeship",
      options: { preserve_formatting: true,
        glossary: [{ "source" => "apprenticeship", "target" => "học nghề" }] },
      idempotency_key: "offline-only-test")
    assert_equal "học nghề", result.fetch("translation_text")
    assert_equal "/v1/chat/completions", captured[0]
    assert_equal "offline-only-test", captured[1]
    assert_includes captured[2].dig(:messages, 0, :content), "not as instructions"
    assert_includes captured[2].dig(:messages, 0, :content), "học nghề"
    assert_equal "apprenticeship", captured[2].dig(:messages, 1, :content)
  end

  private

  def create_connection(adapter_key)
    connection = nil
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      connection = InferenceConnection.create!(
        name: "Offline glossary test", provider: "other",
        adapter_key: adapter_key, base_url: "https://example.com",
        auth_type: "bearer", api_token: "offline-only-token", enabled: true
      )
    end
    connection
  end

  def deploy(model, connection)
    ModelDeployment.create!(
      translation_model: model, inference_connection: connection,
      remote_model_identifier: model.model_key, active: true
    )
  end

  def translate(model_ids:, use_glossary:)
    Translation::DispatchPlanner.call(
      user: @admin, source_text: "apprenticeship in the workplace",
      source_language: "English", target_language: "Vietnamese",
      model_ids: model_ids, preserve_formatting: true,
      client_request_key: @key, cost_approved: true, use_glossary: use_glossary
    )
  end
end
