require "test_helper"

class TranslationStudioTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "Studio integration test password 2026!"

  setup do
    @admin = User.create!(
      email: "studio-#{SecureRandom.hex(6)}@example.test",
      password: PASSWORD,
      password_confirmation: PASSWORD,
      role: "admin"
    )
    @model = TranslationModel.create!(
      model_key: "studio_model_#{SecureRandom.hex(5)}",
      display_name: "Studio test model", active: true
    )
    post login_path, params: { email: @admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  test "studio keeps the existing paid-request approval contract and adds read-only controls" do
    assert_no_enqueued_jobs { get new_admin_translation_path }
    assert_response :success
    assert_select "head > title", text: "Rails 8 Multilingual AI Translation | Translate and compare models"
    assert_select "form[data-controller='translation-form'][action='#{admin_translations_path}']", count: 1
    assert_select "input[name='client_request_key'][type='hidden']", count: 1
    assert_select "input[name='cost_approved'][type='hidden'][value='0']", count: 1
    assert_select "[data-translation-form-target='sourceLanguage'][name='source_language']", count: 1
    assert_select "[data-translation-form-target='targetLanguage'][name='target_language']", count: 1
    assert_select "button[type='button'][data-action='click->translation-form#swapLanguages']", count: 1
    assert_select "textarea[name='source_text'][data-action='input->translation-form#updateText']", count: 1
    assert_select "[data-translation-form-target='characterCount']", count: 1
    assert_select "[data-translation-form-target='wordCount']", count: 1
    assert_select "[data-translation-form-target='lengthNotice'][hidden]", count: 1
    assert_select ".studio-limit", count: 0
    assert_select "#studio_source_limits.studio-gateway-note", count: 1
    assert_select "#studio_source_limits h3#studio_source_limits_heading", text: "Text length limits", count: 1
    assert_select "#studio_source_limits ul.studio-gateway-list li", count: 2
    assert_select "#studio_source_limits ul li:first-child", text: /Translation Gateway v1: Maximum 1,000 Unicode characters/, count: 1
    assert_select "#studio_source_limits ul li:last-child", text: /Other endpoints: Limits depend on the deployed protocol and model/, count: 1
    assert_select "#studio_source_limits p.studio-gateway-extra", text: /Long text is not automatically split/, count: 1
    assert_select "textarea[name='source_text']:not([maxlength])", count: 1
    assert_select "[data-translation-form-app-limit-value='20000']", count: 1
    assert_select "input#studio-select-all-models[type='checkbox'][data-translation-form-target='selectAll'][data-action='change->translation-form#toggleAll'][disabled]", count: 1
    assert_select "label[for='studio-select-all-models']", text: /Select all/
    assert_select ".studio-select-all-note", text: /up to 4 per request/
    assert_select "input#studio-select-all-models[name]", count: 0
    assert_select "details.studio-advanced input[name='preserve_formatting'][checked]", count: 1
    assert_select "p#preserve_formatting_help", text: /not a guarantee of exact formatting/
    assert_select "input[name='model_ids[]'][type='checkbox'][data-translation-form-target='checkbox']", minimum: 1
    assert_select "input[name='model_ids[]'][disabled]", minimum: 1
    assert_select "input[type='submit'][value='Translate text']", count: 1
    assert_select ".studio-setup-note a[href='#{admin_settings_inference_path}']", count: 1
  end

  test "studio is localized in Vietnamese without hardcoded supported-language choices" do
    patch preferences_path, params: { ui_locale: "vi", return_to: new_admin_translation_path }
    assert_redirected_to new_admin_translation_path

    assert_no_enqueued_jobs { get new_admin_translation_path }
    assert_response :success
    assert_select 'html[lang="vi"]'
    assert_select ".studio-heading .app-eyebrow", text: /KHÔNG GIAN DỊCH THUẬT/
    assert_select "button[aria-label='Hoán đổi ngôn ngữ nguồn và đích']", count: 1
    assert_select "details.studio-advanced summary", text: /Tùy chọn nâng cao/
    assert_select "[data-translation-form-target='characterCount']", text: /0 ký tự/
    assert_select ".studio-limit", count: 0
    assert_select "#studio_source_limits h3#studio_source_limits_heading", text: "Giới hạn độ dài văn bản", count: 1
    assert_select "#studio_source_limits ul.studio-gateway-list li", count: 2
    assert_select "#studio_source_limits ul li:first-child", text: /Translation Gateway v1: Tối đa 1.000 ký tự Unicode/, count: 1
    assert_select "#studio_source_limits ul li:last-child", text: /Các endpoint khác: Giới hạn phụ thuộc vào giao thức và model/, count: 1
    assert_select "#studio_source_limits p.studio-gateway-extra", text: /chưa tự động chia văn bản dài/, count: 1
    assert_select "label[for='studio-select-all-models']", text: /Chọn tất cả/
    assert_select ".studio-select-all-note", text: /tối đa 4 model/
    assert_select "input[name='source_language'][type='text'][value='en']", count: 1
    assert_select "input[name='target_language'][type='text'][value='vi']", count: 1
    assert_select "select[name='source_language']", count: 0
    assert_select "select[name='target_language']", count: 0
  end

  test "select all is enabled when a model has a usable connection and never triggers inference" do
    connection = nil
    Translation::SafeEndpoint.stub(:parse!, URI("https://example.com")) do
      connection = InferenceConnection.create!(
        name: "Offline test connection", provider: "other",
        adapter_key: "translation_gateway_v1",
        base_url: "https://example.com", auth_type: "bearer",
        api_token: "offline-test-token", enabled: true
      )
    end
    ModelDeployment.create!(
      translation_model: @model, inference_connection: connection,
      remote_model_identifier: @model.model_key, active: true
    )

    assert_no_enqueued_jobs { get new_admin_translation_path }
    assert_response :success
    assert_select "input#studio-select-all-models[type='checkbox']:not([disabled])", count: 1
    assert_select "input[name='model_ids[]'][value='#{@model.id}']:not([disabled])", count: 1
    assert_select "input#studio-select-all-models[name]", count: 0
    assert_select ".studio-model-limit", text: /Maximum 1000 Unicode characters per request/, count: 1
    assert_select "input[name='model_ids[]'][value='#{@model.id}'][data-max-source-length='1000'][data-model-name='Studio test model']", count: 1
    assert_select ".studio-select-all-note", text: /up to 4 per request/
    assert_select "input[name='cost_approved'][value='0']", count: 1
  end

  test "comparison offers 2 and 4 columns and marks completed output without new inference" do
    translation = @admin.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_text: "Hello\nOriginal text",
      source_language: "English", target_language: "Vietnamese",
      ui_locale: "en"
    )
    alternative = TranslationModel.create!(
      model_key: "studio_other_#{SecureRandom.hex(5)}",
      display_name: "Another translation model", active: true
    )
    first = translation.translation_runs.create!(
      translation_model: @model, status: "completed", attempt_no: 1,
      translation_text: "Xin chào\nBản dịch đầu tiên"
    )
    second = translation.translation_runs.create!(
      translation_model: alternative, status: "completed", attempt_no: 1,
      translation_text: "Chào bạn\nMột bản dịch khác"
    )
    translation.update!(preferred_model: @model)

    assert_no_enqueued_jobs { get admin_translation_path(translation) }
    assert_response :success
    assert_select ".translation-compare-workspace[data-controller='translation-compare']", count: 1
    assert_select "button[data-action='click->translation-compare#twoColumns'][aria-pressed='true']", count: 1
    assert_select "button[data-action='click->translation-compare#fourColumns'][aria-pressed='false']", count: 1
    assert_select "button[data-action='click->translation-compare#toggleDifferences']", count: 1
    assert_select "section#translation_results_#{translation.id}.translation-result-grid[data-translation-compare-target='results']", count: 1
    assert_select "article[data-translation-compare-completed='true']", count: 2
    assert_select "article[data-translation-compare-preferred='true']", count: 1
    assert_select "article##{ActionView::RecordIdentifier.dom_id(first)} pre[data-clipboard-target='content'][data-translation-compare-target='content']", text: /Xin chào/
    assert_select "article##{ActionView::RecordIdentifier.dom_id(second)} pre[data-translation-compare-target='content']", text: /Chào bạn/
    assert_select "article.translation-card-selected", count: 1
    assert_select "button[data-action='click->clipboard#expand']", count: 2
    assert_select "button[data-action='click->clipboard#copy']", count: 2
    assert_select "p.compare-disclaimer", text: /not a translation-quality score/
    assert_select "section#translation_source_#{translation.id} pre", text: /Original text/
  end

  test "safe progress endpoint continues updating result cards with comparison targets" do
    translation = @admin.translation_requests.create!(
      client_request_key: SecureRandom.uuid, source_text: "Private example",
      source_language: "en", target_language: "vi", ui_locale: "en"
    )
    translation.translation_runs.create!(
      translation_model: @model, status: "completed", attempt_no: 1, translation_text: "Xin chào"
    )

    assert_no_enqueued_jobs do
      get progress_admin_translation_path(translation),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
    assert_includes response.body, "translation_results_#{translation.id}"
    assert_includes response.body, 'data-translation-compare-target="results"'
    assert_includes response.body, 'data-translation-compare-target="content"'
    assert_includes response.body, "Xin chào"
  end
end
