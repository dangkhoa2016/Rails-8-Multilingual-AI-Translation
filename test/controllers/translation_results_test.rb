require "test_helper"

class TranslationResultsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "A safe example password 2026!"

  setup do
    @admin = User.create!(
      email: "translations-admin-#{SecureRandom.hex(5)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    @model = TranslationModel.create!(
      model_key: "results_test_#{SecureRandom.hex(5)}",
      display_name: "Results test model", active: true
    )
    sign_in!
  end

  test "new translation form explains preserve formatting in English and Vietnamese" do
    assert_no_enqueued_jobs do
      get new_admin_translation_path
      assert_response :success
      assert_select "input[type='checkbox'][name='preserve_formatting'][checked][aria-describedby='preserve_formatting_help']", count: 1
      assert_select "label[for='preserve_formatting']", text: "Preserve formatting", count: 1
      assert_select "p#preserve_formatting_help", text: /not a guarantee of exact formatting/, count: 1

      patch preferences_path, params: { ui_locale: "vi", return_to: new_admin_translation_path }
      assert_redirected_to new_admin_translation_path
      get new_admin_translation_path
      assert_response :success
      assert_select "input[type='checkbox'][name='preserve_formatting'][checked][aria-describedby='preserve_formatting_help']", count: 1
      assert_select "label[for='preserve_formatting']", text: "Giữ nguyên định dạng", count: 1
      assert_select "p#preserve_formatting_help", text: /không bảo đảm giữ nguyên định dạng tuyệt đối/, count: 1
    end
  end

  test "POST records a translation and redirected GET renders the result without provider inference" do
    assert_no_enqueued_jobs do
      post admin_translations_path, params: {
        client_request_key: SecureRandom.uuid,
        cost_approved: "1",
        source_language: "en",
        target_language: "vi",
        source_text: "Hello from the translation form",
        preserve_formatting: "1",
        model_ids: [@model.id]
      }
      assert_response :redirect

      translation = TranslationRequest.order(:created_at).last!
      assert_redirected_to admin_translation_path(translation)
      assert_equal "failed", translation.translation_runs.first.status
      assert_equal "NOT_CONFIGURED", translation.translation_runs.first.error_code

      follow_redirect!
      assert_response :success
      assert_select "h2", text: /Original text/
      assert_select "article##{ActionView::RecordIdentifier.dom_id(translation.translation_runs.first)}", count: 1
      assert_select "[data-controller='translation-progress']", count: 1
      assert_select "section#translation_progress_#{translation.id}", count: 1
    end
  end

  test "progress GET renders live model counts without enqueuing a provider job" do
    translation = create_translation!
    translation.update_column(:status, "running")
    translation.translation_runs.first!.update_column(:status, "running")

    model2 = TranslationModel.create!(
      model_key: "progress_test_#{SecureRandom.hex(4)}", display_name: "Progress model", active: true
    )
    translation.translation_runs.create!(
      translation_model: model2, status: "completed", attempt_no: 1,
      translation_text: "Xin chào"
    )

    assert_no_enqueued_jobs do
      get progress_admin_translation_path(translation), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_match %r{text/vnd.turbo-stream.html}, response.media_type
    assert_includes response.body, "translation_header_status_#{translation.id}"
    assert_includes response.body, "translation_progress_#{translation.id}"
    assert_includes response.body, "translation_results_#{translation.id}"
    assert_includes response.body, "1/2 model runs processed (50%)"
    assert_includes response.body, "Completed: 1"
    assert_equal "false", response.headers["X-Translation-Terminal"]
    assert_includes response.headers["Cache-Control"], "no-store"

    version = response.headers["X-Progress-Version"]
    assert version.present?
    assert_no_enqueued_jobs do
      get progress_admin_translation_path(translation),
        headers: { "X-Progress-Version" => version, "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :no_content
    assert_equal "false", response.headers["X-Translation-Terminal"]
  end

  test "progress GET completes for terminal models without provider work" do
    translation = create_translation!
    translation.translation_runs.first!.update_column(:status, "failed")
    translation.update_column(:status, "failed")

    assert_no_enqueued_jobs do
      get progress_admin_translation_path(translation)
    end
    assert_response :success
    assert_equal "true", response.headers["X-Translation-Terminal"]
    assert_includes response.body, "1/1 model runs processed (100%)"
    assert_includes response.body, "Failed: 1"
  end

  test "progress GET cannot inspect another administrator's translation" do
    other = User.create!(
      email: "other-#{SecureRandom.hex(4)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    translation = other.translation_requests.create!(
      client_request_key: SecureRandom.uuid, source_text: "Protected text",
      source_language: "en", target_language: "vi", ui_locale: "en"
    )
    assert_no_enqueued_jobs do
      get progress_admin_translation_path(translation)
    end
    assert_response :not_found
    refute_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "show is authorized with the Pundit show? predicate" do
    translation = create_translation!
    get admin_translation_path(translation)

    assert_response :success
    assert_select "pre", text: /Sample/
    assert_select "section#translation_source_#{translation.id}[data-controller='translation-source']", count: 1
    assert_select "button[data-action='click->translation-source#toggle']", count: 0
    assert_select "article##{ActionView::RecordIdentifier.dom_id(translation.translation_runs.first)}", count: 1
  end

  test "show renders four completed model results without external requests" do
    translation = create_translation!
    translation.update_column(:status, "completed")
    translation.translation_runs.first!.update_column(:status, "completed")

    3.times do |index|
      model = TranslationModel.create!(
        model_key: "four_results_#{index}_#{SecureRandom.hex(4)}",
        display_name: "Completed model #{index + 2}", active: true
      )
      translation.translation_runs.create!(
        translation_model: model, status: "completed", attempt_no: 1,
        translation_text: "Test translation #{index + 2}"
      )
    end

    assert_no_enqueued_jobs do
      get admin_translation_path(translation)
    end
    assert_response :success
    assert_select "article[id^='translation_run_']", count: 4
    assert_select "pre[data-clipboard-target='content']", text: /Test translation 2/, count: 1
    assert_select "details summary", text: /Technical details/, count: 4
    assert_select "pre.translation-raw-response", count: 4
    assert_select "article.min-w-0", count: 4
    assert_select "article button[data-action='click->clipboard#expand'] svg", count: 4
    assert_select "article button[data-action='click->clipboard#expand'] [data-clipboard-target='expandLabel']", text: /Expand/, count: 4
    assert_select "article button[data-action='click->clipboard#copy'] svg", count: 4
    assert_select "article button[data-action='click->clipboard#copy'] [data-clipboard-target='copyLabel']", count: 4
    assert_select "p", text: /Connection: Not configured/, count: 4
    assert_select "p", text: /Choose the best translation/
    assert_select "pre", text: /Locally recorded/, count: 0
  end

  test "unchanged output is flagged and an encrypted saved response can be inspected without provider calls" do
    translation = create_translation!
    run = translation.translation_runs.first!
    snapshot = Translation::ProviderResponseSnapshot.gateway(
      payload: { "job_id" => SecureRandom.uuid, "status" => "completed" },
      run: { "model" => @model.model_key, "status" => "completed",
        "translation_text" => "Sample text", "is_mock_result" => false,
        "usage" => { "total_tokens" => 12 } }
    )
    run.update!(status: "completed", translation_text: "Sample text",
      provider_response_json: snapshot)

    assert_no_enqueued_jobs { get admin_translation_path(translation) }
    assert_response :success
    assert_select "p", text: /identical to the input/
    assert_select "pre", text: /"total_tokens": 12/
    assert_select "p", text: /Only allowlisted API fields/
    assert_not_includes TranslationRun.connection.select_value(
      "SELECT provider_response_json FROM translation_runs WHERE id = #{TranslationRun.connection.quote(run.id)}"
    ), "Sample text"
  end

  test "preference buttons distinguish the selected translation and allow switching without inference" do
    translation = create_translation!
    run = translation.translation_runs.first!
    run.update_columns(status: "completed", translation_text: nil)
    other_model = TranslationModel.create!(
      model_key: "preferred_test_#{SecureRandom.hex(4)}",
      display_name: "Alternative model", active: true
    )
    translation.translation_runs.create!(
      translation_model: other_model, status: "completed", attempt_no: 1,
      translation_text: "Another result"
    )

    assert_no_enqueued_jobs do
      patch prefer_admin_translation_path(translation), params: { model_id: @model.id }
    end
    assert_equal @model.id, translation.reload.preferred_model_id

    get admin_translation_path(translation)
    assert_response :success
    assert_select "section#translation_source_#{translation.id} button[data-action='click->translation-source#toggle']", text: /View selected translation/, count: 1
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='original'] pre",
      text: /Sample text/, count: 1
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='selected'].translation-comparison-reveal[aria-hidden='true'] pre",
      text: /Sample text/, count: 0
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='selected'].translation-comparison-reveal[aria-hidden='true']",
      count: 1
    assert_select "section#translation_source_#{translation.id} button[aria-expanded='false']", count: 1
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='label']", text: /View selected translation/, count: 1
    assert_select "article.translation-card-selected", count: 1
    assert_select "article##{ActionView::RecordIdentifier.dom_id(run)}.translation-card-selected", count: 1
    assert_select "article.translation-card-selected button.translation-preference-selected[disabled]", text: /Selected translation/, count: 1
    assert_select "div.mt-3.flex.justify-center form[data-turbo='true'] button.translation-preference-action",
      text: /Choose this translation/, count: 1

    assert_no_enqueued_jobs do
      patch prefer_admin_translation_path(translation), params: { model_id: other_model.id }
    end
    assert_equal other_model.id, translation.reload.preferred_model_id
    get admin_translation_path(translation)
    assert_select "article.translation-card-selected", count: 1
    assert_select "article##{ActionView::RecordIdentifier.dom_id(run)}.translation-card-selected", count: 0
    assert_select "article.translation-card-selected button.translation-preference-selected[disabled]", count: 1
    assert_select "div.mt-3.flex.justify-center form button.translation-preference-action", count: 1
  end

  test "choosing a translation returns targeted Turbo Streams without full-page navigation or provider calls" do
    translation = create_translation!
    first = translation.translation_runs.first!
    first.update!(status: "completed", translation_text: "First translated output")
    second_model = TranslationModel.create!(
      model_key: "stream_prefer_#{SecureRandom.hex(4)}",
      display_name: "Second model", active: true
    )
    second = translation.translation_runs.create!(
      translation_model: second_model, status: "completed", attempt_no: 1,
      translation_text: "Second translated output"
    )
    headers = { "Accept" => "text/vnd.turbo-stream.html" }

    assert_no_enqueued_jobs do
      patch prefer_admin_translation_path(translation), params: { model_id: @model.id }, headers: headers
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal @model.id, translation.reload.preferred_model_id
    assert_select "turbo-stream[action='replace'][target='translation_source_#{translation.id}']", count: 1
    assert_select "turbo-stream[action='replace'][target='#{ActionView::RecordIdentifier.dom_id(first)}']", count: 1
    assert_select "turbo-stream[target='#{ActionView::RecordIdentifier.dom_id(second)}']", count: 0
    assert response.body.lstrip.start_with?("<turbo-stream"), "Expected Turbo Stream fragments, not a full page"
    assert_includes response.body, "First translated output"
    assert_includes response.body, "Hide selected translation"
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] .translation-comparison-reveal.is-open[aria-hidden='false']",
      count: 1
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] button[aria-expanded='true']", count: 1
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] [data-translation-source-target='original'] pre",
      text: /Sample text/, count: 1

    assert_no_enqueued_jobs do
      patch prefer_admin_translation_path(translation), params: { model_id: second_model.id }, headers: headers
    end
    assert_response :success
    assert_equal second_model.id, translation.reload.preferred_model_id
    assert_select "turbo-stream[action='replace'][target='translation_source_#{translation.id}']", count: 1
    assert_select "turbo-stream[action='replace'][target='#{ActionView::RecordIdentifier.dom_id(first)}']", count: 1
    assert_select "turbo-stream[action='replace'][target='#{ActionView::RecordIdentifier.dom_id(second)}']", count: 1
    assert response.body.lstrip.start_with?("<turbo-stream"), "Expected Turbo Stream fragments, not a full page"
    assert_includes response.body, "Second translated output"
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] .translation-comparison-reveal.is-open[aria-hidden='false'] pre",
      text: /Second translated output/, count: 1
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] .translation-comparison-reveal pre",
      text: /First translated output/, count: 0
    assert_select "turbo-stream[target='translation_source_#{translation.id}'] button[aria-expanded='true']", count: 1

    get admin_translation_path(translation)
    assert_response :success
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='original'] pre",
      text: /Sample text/, count: 1
    assert_select "section#translation_source_#{translation.id} [data-translation-source-target='selected'].translation-comparison-reveal[aria-hidden='true'] pre",
      text: /Second translated output/, count: 1
    assert_select "section#translation_source_#{translation.id} button[aria-expanded='false']", count: 1
    assert_select "section#translation_source_#{translation.id}[data-translation-source-hide-selected-value='Hide selected translation']", count: 1
  end

  test "refresh_status is authorized using refresh_status? without submitting inference" do
    translation = create_translation!
    assert_no_enqueued_jobs do
      post refresh_status_admin_translation_path(translation)
    end
    assert_redirected_to admin_translation_path(translation)
  end

  test "prefer is authorized using prefer? without submitting inference" do
    translation = create_translation!
    run = translation.translation_runs.first!
    # No provider work or broadcast is needed to set up a completed fixture.
    run.update_columns(status: "completed", translation_text: nil)

    assert_no_enqueued_jobs do
      patch prefer_admin_translation_path(translation), params: { model_id: @model.id }
    end
    assert_redirected_to admin_translation_path(translation)
    assert_equal @model.id, translation.reload.preferred_model_id
  end

  private

  def sign_in!
    post login_path, params: { email: @admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  def create_translation!
    translation = @admin.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_text: "Sample text",
      source_language: "en",
      target_language: "vi",
      ui_locale: "en",
      status: "queued"
    )
    translation.translation_runs.create!(translation_model: @model, status: "queued", attempt_no: 1)
    translation
  end
end
