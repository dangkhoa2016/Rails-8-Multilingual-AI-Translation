require "test_helper"

class TranslationHistoryExportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "A valid secure test password 2026!"

  setup do
    @admin = User.create!(
      email: "history-admin-#{SecureRandom.hex(5)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    @other = User.create!(
      email: "history-other-#{SecureRandom.hex(5)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    @model = TranslationModel.create!(
      model_key: "history_model_#{SecureRandom.hex(5)}", display_name: "History model", active: true
    )
    post login_path, params: { email: @admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  test "history includes local filters, no provider requests, and safe empty state" do
    assert_no_enqueued_jobs { get admin_translations_path }
    assert_response :success
    assert_select "form[action='#{admin_translations_path}'][method='get']", count: 1
    assert_select "input[name='q'][maxlength='80']", count: 1
    assert_select "select[name='status']", count: 1
    assert_select "input[name='source_language']", count: 1
    assert_select "input[name='target_language']", count: 1
    assert_select "input[name='from'][type='date']", count: 1
    assert_select "input[name='to'][type='date']", count: 1
    assert_select ".history-search-privacy", text: /not encrypted source text/, count: 1
    assert_select ".app-empty-state", text: /No translations yet/
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "pagination exposes all sessions beyond the former 100-row cutoff" do
    105.times do |index|
      make_session(owner: @admin, source: "en", target: "vi",
        source_text: "History row #{index}",
        created_at: Time.current - (105 - index).minutes)
    end
    assert_no_enqueued_jobs { get admin_translations_path }
    assert_response :success
    assert_select "a.history-record", count: 20
    assert_select ".history-filter-description", text: /105 matching sessions/
    assert_select ".history-pagination p", text: /Showing 1–20 of 105/
    assert_select "a[rel='next']", count: 1

    assert_no_enqueued_jobs { get admin_translations_path(page: 6) }
    assert_response :success
    assert_select "a.history-record", count: 5
    assert_select ".history-pagination p", text: /Showing 101–105 of 105/
    assert_select "a[rel='next']", count: 0

    get admin_translations_path(page: "9999999")
    assert_response :success
    assert_select "a.history-record", count: 5
  end

  test "search filters language labels, UUID session ID, status and date without decrypting all rows" do
    english = make_session(owner: @admin, source: "English", target: "Vietnamese", source_text: "private phrase",
      status: "completed", created_at: Time.zone.local(2026, 10, 3, 12, 0, 0))
    make_session(owner: @admin, source: "fr", target: "de", source_text: "hidden text",
      status: "failed", created_at: Time.zone.local(2026, 11, 8, 12, 0, 0))
    make_session(owner: @other, source: "English", target: "Vietnamese",
      source_text: "not for current user", status: "completed")

    assert_no_enqueued_jobs do
      get admin_translations_path(q: "english", status: "completed", from: "2026-10-03", to: "2026-10-03")
    end
    assert_response :success
    assert_select "a.history-record", count: 1
    assert_select "a.history-record[href='#{admin_translation_path(english)}']", count: 1
    assert_select "a.history-record", text: /not for current user/, count: 0

    get admin_translations_path(q: "##{english.id}")
    assert_response :success
    assert_select "a.history-record", count: 1

    # Source text is encrypted; querying private text must not cause a full-table decrypt/search.
    get admin_translations_path(q: "private phrase")
    assert_response :success
    assert_select "a.history-record", count: 0
    assert_select ".app-empty-state", text: /No sessions match these filters/

    get admin_translations_path(source_language: "fr", target_language: "de", status: "failed")
    assert_response :success
    assert_select "a.history-record", count: 1

    get admin_translations_path(from: "bad-date", to: "2026-99-90", status: "nonexistent")
    assert_response :success
  end

  test "filtered pagination preserves parameters and returns only the scoped user's sessions" do
    24.times do |index|
      make_session(owner: @admin, source: "English", target: "Vietnamese",
        source_text: "Filtered row #{index}", status: "completed")
    end
    make_session(owner: @admin, source: "English", target: "German", status: "failed")
    make_session(owner: @other, source: "English", target: "Vietnamese", status: "completed")
    assert_no_enqueued_jobs do
      get admin_translations_path(q: "English", status: "completed",
        target_language: "Vietnamese", page: 2)
    end
    assert_response :success
    assert_select "a.history-record", count: 4
    assert_select "a[rel='prev'][href*='status=completed']", count: 1
    assert_select "a[rel='prev'][href*='target_language=Vietnamese']", count: 1
    assert_select "a[rel='prev'][href*='q=English']", count: 1
  end

  test "only an owner can download UTF-8 TXT, Markdown or allowlisted JSON" do
    source = "Private 📖\n```\nOriginal text"
    translated = "Xin chào 🧭\n```\nTranslated block"
    translation = make_session(owner: @admin, source: "English", target: "Vietnamese",
      source_text: source, status: "completed")
    run = translation.translation_runs.create!(
      translation_model: @model, status: "completed", attempt_no: 1,
      translation_text: translated, is_mock_result: true,
      provider_response_json: '{"secret":"provider-hidden-token"}'
    )
    translation.update!(preferred_model: @model)

    assert_no_enqueued_jobs do
      get export_admin_translation_path(translation, file_format: "txt")
    end
    assert_response :success
    assert_includes response.media_type, "text/plain"
    assert_includes response.headers.fetch("Content-Disposition"), "attachment"
    assert_includes response.body, source
    assert_includes response.body, translated
    assert_includes response.body, "Simulated result"
    assert_not_includes response.body, "provider-hidden-token"
    assert_includes response.headers["Cache-Control"], "no-store"

    assert_no_enqueued_jobs { get export_admin_translation_path(translation, file_format: "md") }
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, source
    assert_includes response.body, translated
    assert_match /`{4,}text\n/, response.body
    assert_not_includes response.body, "provider-hidden-token"

    assert_no_enqueued_jobs { get export_admin_translation_path(translation, file_format: "json") }
    assert_response :success
    assert_equal "application/json", response.media_type
    data = JSON.parse(response.body)
    assert_equal "1.0", data.fetch("schema_version")
    assert_equal source, data.dig("session", "source_text")
    assert_equal translated, data.fetch("results").first.fetch("translation_text")
    assert_equal true, data.fetch("results").first.fetch("preferred")
    assert_equal true, data.fetch("results").first.fetch("is_mock_result")
    assert_equal run.translation_model.model_key, data.fetch("results").first.fetch("model_key")
    assert_not data.to_json.include?("provider_response_json")
    assert_not data.to_json.include?("provider-hidden-token")
  end

  test "unknown export format and another owner's exports are rejected" do
    own = make_session(owner: @admin)
    other = make_session(owner: @other, source_text: "Someone else's confidential content")
    assert_no_enqueued_jobs do
      get export_admin_translation_path(own, file_format: "csv")
    end
    assert_response :not_found
    assert_no_enqueued_jobs do
      get export_admin_translation_path(other, file_format: "json")
    end
    assert_response :not_found
    assert_not_includes response.body, "Someone else's confidential content"
    assert_no_enqueued_jobs do
      get admin_translations_path(q: "Someone else's confidential content")
    end
    assert_select "a.history-record", count: 0
  end

  test "Vietnamese history and exports use local labels without provider calls" do
    translation = make_session(owner: @admin, source_text: "Chào bạn", status: "completed")
    translation.translation_runs.create!(
      translation_model: @model, status: "completed",
      attempt_no: 1, translation_text: "Hello"
    )
    patch preferences_path, params: { ui_locale: "vi", return_to: admin_translations_path }

    assert_no_enqueued_jobs { get admin_translations_path(status: "completed") }
    assert_response :success
    assert_select "h2#history-filter-title", text: /Tìm phiên dịch/
    assert_select "h2#history-results-heading", text: /Các phiên đã lưu/
    assert_select ".history-search-privacy", text: /không tìm trong nội dung gốc đã mã hóa/

    assert_no_enqueued_jobs { get admin_translation_path(translation) }
    assert_response :success
    assert_select ".history-export-heading", text: /Tải kết quả/
    assert_select "a.history-export-link", count: 3

    assert_no_enqueued_jobs { get export_admin_translation_path(translation, file_format: "txt") }
    assert_response :success
    assert_includes response.body, "Văn bản gốc"
    assert_includes response.body, "Chào bạn"
  end

  private

  def make_session(owner:, source: "en", target: "vi", source_text: "Sample source",
      status: "queued", created_at: Time.current)
    owner.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_language: source, target_language: target,
      source_text: source_text, ui_locale: "en", status: status, created_at: created_at
    )
  end
end
