require "test_helper"

class GlossaryHelpTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PASSWORD = "Glossary-safe test password 2026!"

  setup do
    @admin = User.create!(
      email: "glossary-admin-#{SecureRandom.hex(5)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    @other = User.create!(
      email: "glossary-other-#{SecureRandom.hex(5)}@example.test",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
    post login_path, params: { email: @admin.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  test "glossary list and Help Center are read-only, localized and linked in sidebar" do
    assert_no_enqueued_jobs do
      get admin_glossary_entries_path
      assert_response :success
      assert_select "a[href='#{admin_glossary_entries_path}']", minimum: 1
      assert_select "a[href='#{admin_help_path}']", minimum: 1
      assert_select "form[method='get'][action='#{admin_glossary_entries_path}']", count: 1
      assert_select ".app-empty-state", text: /No glossary terms yet/
      assert_includes response.headers["Cache-Control"], "no-store"

      get admin_help_path
      assert_response :success
      assert_select "details.help-faq", count: 9
      assert_select "h1", text: "Help Center"
      assert_includes response.body, "Gateway v1"

      patch preferences_path, params: { ui_locale: "vi", return_to: admin_help_path }
      get admin_glossary_entries_path
      assert_select "h1", text: "Bảng thuật ngữ dịch"
      get admin_help_path
      assert_select "h1", text: "Trung tâm trợ giúp"
      assert_select ".help-faq", text: /1.000 ký tự/
    end
  end

  test "create, edit, disable and delete glossary entries with encrypted values" do
    attributes = {
      source_language: "English", target_language: "Vietnamese",
      source_term: "apprenticeship", target_term: "học nghề",
      notes: "Do not send this private note", active: "1"
    }
    assert_no_enqueued_jobs do
      assert_difference "GlossaryEntry.count", 1 do
        post admin_glossary_entries_path, params: { glossary_entry: attributes }
      end
    end
    assert_redirected_to admin_glossary_entries_path
    entry = @admin.glossary_entries.last!
    assert entry.active?
    assert_equal "học nghề", entry.target_term
    assert_equal "Do not send this private note", entry.notes
    raw_source = GlossaryEntry.connection.select_value(
      GlossaryEntry.sanitize_sql_array(["SELECT source_term FROM glossary_entries WHERE id = ?", entry.id])
    )
    refute_includes raw_source, "apprenticeship"

    get admin_glossary_entries_path
    assert_response :success
    assert_select "article#glossary_entry_#{entry.id}", text: /apprenticeship/
    get edit_admin_glossary_entry_path(entry)
    assert_response :success
    assert_select "input[name='glossary_entry[source_term]'][value='apprenticeship']", count: 1

    patch admin_glossary_entry_path(entry), params: {
      glossary_entry: { target_term: "học việc", active: "0" }
    }
    assert_redirected_to admin_glossary_entries_path
    assert_equal "học việc", entry.reload.target_term
    assert_not entry.active?

    assert_difference "GlossaryEntry.count", -1 do
      delete admin_glossary_entry_path(entry)
    end
    assert_redirected_to admin_glossary_entries_path
  end

  test "invalid glossary terms cannot be stored and do not trigger inference" do
    assert_no_enqueued_jobs do
      assert_no_difference "GlossaryEntry.count" do
        post admin_glossary_entries_path, params: { glossary_entry: {
          source_language: "English", target_language: "vi",
          source_term: "", target_term: "translated",
          notes: "Something", active: "1"
        } }
      end
    end
    assert_response :unprocessable_entity
    assert_select ".glossary-errors", text: /Source term/
  end

  test "another account cannot view, edit, update or delete private glossary entries" do
    foreign = @other.glossary_entries.create!(
      source_language: "en", target_language: "vi",
      source_term: "secret foreign term", target_term: "bí mật riêng"
    )
    own = @admin.glossary_entries.create!(
      source_language: "fr", target_language: "de",
      source_term: "own term", target_term: "eigener Begriff"
    )
    get admin_glossary_entries_path
    assert_response :success
    assert_select "article#glossary_entry_#{foreign.id}", count: 0
    assert_select "article#glossary_entry_#{own.id}", count: 1
    refute_includes response.body, "secret foreign term"

    get edit_admin_glossary_entry_path(foreign)
    assert_response :not_found
    patch admin_glossary_entry_path(foreign),
      params: { glossary_entry: { source_term: "stolen" } }
    assert_response :not_found
    delete admin_glossary_entry_path(foreign)
    assert_response :not_found
    assert_equal "secret foreign term", foreign.reload.source_term
  end

  test "language and active filters plus pagination stay scoped to the current account" do
    25.times do |index|
      @admin.glossary_entries.create!(
        source_language: "en", target_language: "vi",
        source_term: "source #{index}", target_term: "target #{index}", active: index.even?
      )
    end
    @other.glossary_entries.create!(
      source_language: "en", target_language: "vi",
      source_term: "foreign", target_term: "foreign", active: true
    )
    get admin_glossary_entries_path
    assert_response :success
    assert_select "article.glossary-entry-row", count: 20
    assert_select "a[rel='next']", count: 1
    get admin_glossary_entries_path(page: 2)
    assert_response :success
    assert_select "article.glossary-entry-row", count: 5

    get admin_glossary_entries_path(source_language: "EN", target_language: "vi", active: "true")
    assert_response :success
    assert_select "article.glossary-entry-row", count: 13
    assert_select ".history-filter-description", text: /13 entries/
  end

  test "Studio only offers glossary when active terms exist" do
    assert_no_enqueued_jobs do
      get new_admin_translation_path
      assert_response :success
      assert_select "input[name='use_glossary'][type='checkbox'][disabled]", count: 1
    end
    @admin.glossary_entries.create!(
      source_language: "en", target_language: "vi",
      source_term: "Rails", target_term: "Rails", active: true
    )
    assert_no_enqueued_jobs { get new_admin_translation_path }
    assert_response :success
    assert_select "input[name='use_glossary'][type='checkbox']:not([disabled])", count: 1
    assert_select "a[href='#{admin_glossary_entries_path}']", minimum: 1
    assert_select ".studio-glossary-help", text: /1 active terms/
  end

  test "saved sessions display frozen glossary count and export allowed term pairs" do
    translation = @admin.translation_requests.create!(
      client_request_key: SecureRandom.uuid,
      source_language: "English", target_language: "Vietnamese",
      source_text: "apprenticeship", ui_locale: "en",
      use_glossary: true,
      glossary_snapshot: JSON.generate([
        { "source" => "apprenticeship", "target" => "học nghề" }
      ])
    )
    assert_no_enqueued_jobs do
      get admin_translation_path(translation)
      assert_response :success
      assert_select ".glossary-used-note", text: /1 matching terms/
      get export_admin_translation_path(translation, file_format: "json")
      assert_response :success
    end
    payload = JSON.parse(response.body)
    assert_equal true, payload.dig("session", "use_glossary")
    assert_equal [{ "source" => "apprenticeship", "target" => "học nghề" }],
      payload.dig("session", "glossary_terms")
    assert_not payload.to_json.include?("private note")
  end
end
