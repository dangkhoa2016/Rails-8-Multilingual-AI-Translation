require "test_helper"

class InferenceConnectionsSettingsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  PASSWORD = "A strong example password 2026!"

  setup do
    %w[hy_mt2_30b index_35b gemma4_31b_it qwen35_35b].each_with_index do |key, index|
      TranslationModel.find_or_create_by!(model_key: key) do |model|
        model.display_name = "Test model #{index + 1}"
        model.position = index
      end
    end
  end

  def administrator
    @administrator ||= User.create!(
      email: "connection-admin-#{SecureRandom.hex(6)}@example.com",
      password: PASSWORD, password_confirmation: PASSWORD, role: "admin"
    )
  end

  def sign_in
    post login_path, params: { email: administrator.email, password: PASSWORD }
    assert_redirected_to admin_translations_path
  end

  def connection_attributes
    {
      name: "Modal translation API",
      provider: "modal",
      adapter_key: "translation_gateway_v1",
      base_url: "https://example.com",
      auth_type: "bearer",
      api_token: "fake-token-for-isolated-tests",
      enabled: "1"
    }
  end

  def create_connection!
    Translation::SafeEndpoint.stub(:parse!, URI.parse("https://example.com")) do
      post admin_settings_inference_connections_path, params: {
        inference_connection: connection_attributes
      }
    end
    assert_redirected_to admin_settings_inference_path
    InferenceConnection.find_by!(name: connection_attributes[:name])
  end

  test "empty connection list shows setup links and disables model deployments" do
    sign_in
    assert_equal 0, InferenceConnection.count
    model_count = TranslationModel.count
    assert_operator model_count, :>, 0

    get admin_settings_inference_path
    assert_response :success
    assert_select "h2", text: /Set up your first provider connection/
    assert_select "a[href='#{new_admin_settings_inference_connection_path}']", minimum: model_count + 1
    assert_select "select[name='inference_connection_id'][disabled]", count: model_count
    assert_select "input[type='submit'][value='Activate deployment'][disabled]", count: model_count

    ids = css_select("select[name='inference_connection_id']").map { |node| node["id"] }
    assert_equal model_count, ids.uniq.length
    assert ids.all? { |value| value.start_with?("model_") }
  end

  test "creating and updating an enabled connection makes it selectable and editable" do
    sign_in
    connection = create_connection!
    assert connection.enabled?
    assert connection.token_configured?

    get admin_settings_inference_path
    assert_response :success
    assert_select "select[name='inference_connection_id'] option[value='#{connection.id}']", count: TranslationModel.count
    assert_select "a[href='#{edit_admin_settings_inference_connection_path(connection)}']", minimum: 1
    assert_select "input[type='submit'][value='Activate deployment']:not([disabled])", count: TranslationModel.count

    get edit_admin_settings_inference_connection_path(connection)
    assert_response :success
    assert_select "input[name='inference_connection[name]'][value='Modal translation API']"

    original_token = connection.api_token
    Translation::SafeEndpoint.stub(:parse!, URI.parse("https://example.com")) do
      patch admin_settings_inference_connection_path(connection), params: {
        inference_connection: connection_attributes.merge(
          name: "Updated connection",
          api_token: ""
        )
      }
    end
    assert_redirected_to admin_settings_inference_path
    assert_equal "Updated connection", connection.reload.name
    assert_equal original_token, connection.api_token
  end

  test "inactive connection is not selectable until enabled" do
    sign_in
    connection = create_connection!
    connection.update_column(:enabled, false)

    get admin_settings_inference_path
    assert_response :success
    assert_select "h2", text: /All provider connections are disabled/
    assert_select "select[name='inference_connection_id'][disabled]", count: TranslationModel.count
    assert_select "a[href='#{edit_admin_settings_inference_connection_path(connection)}']", minimum: 1
  end

  test "catalog check renders a modal and provides JSON feedback without real inference" do
    sign_in
    connection = create_connection!

    get admin_settings_inference_path
    assert_response :success
    assert_select '[data-controller="connection-probe"]', count: 1
    assert_select 'dialog[data-connection-probe-target="dialog"]', count: 1
    assert_select "form[action='#{check_connection_admin_settings_inference_connection_path(connection)}'] button[data-action='click->connection-probe#open']", count: 1
    assert_select 'button[data-connection-probe-target="start"]', count: 1

    fake = Object.new
    fake.define_singleton_method(:connection_check) do
      { "models" => [{ "id" => "mock-model-a" }, { "id" => "mock-model-b" }] }
    end
    Translation::AdapterRouter.stub(:build, fake) do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
    end

    assert_response :success
    payload = response.parsed_body
    assert_equal true, payload["ok"]
    assert_equal "reachable", payload["status"]
    assert_equal 2, payload["model_count"]
    assert_equal ["mock-model-a", "mock-model-b"], payload["models"]
    assert payload["checked_at"].present?
    assert connection.reload.last_checked_at.present?
    assert_equal "reachable", connection.last_check_status
    refute_includes response.body, "fake-token-for-isolated-tests"
  end

  test "catalog check extracts model keys from the real translation gateway schema" do
    sign_in
    connection = create_connection!

    # The upstream /v1/models contract returns "key", not "id" or "name".
    model_keys = %w[hy_mt2_30b index_translate_35b gemma_4 qwen_3_5]
    upstream_catalog = {
      "models" => model_keys.map do |key|
        { "key" => key, "enabled" => true, "runtime_verified" => true,
          "checkpoint" => "ignored-in-public-probe-output" }
      end
    }
    adapter = Object.new
    adapter.define_singleton_method(:connection_check) { upstream_catalog }

    Translation::AdapterRouter.stub(:build, adapter) do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
    end

    assert_response :success
    payload = response.parsed_body
    assert_equal true, payload["ok"]
    assert_equal "reachable", payload["status"]
    assert_equal model_keys.length, payload["model_count"]
    assert_equal model_keys, payload["models"]
    refute_includes response.body, "ignored-in-public-probe-output"
  end

  test "catalog check JSON reports upstream failure and records outcome" do
    sign_in
    connection = create_connection!
    failing = Object.new
    failing.define_singleton_method(:connection_check) do
      raise Translation::HttpClient::HttpError, 401
    end

    Translation::AdapterRouter.stub(:build, failing) do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
    end
    assert_response :bad_gateway
    payload = response.parsed_body
    assert_equal false, payload["ok"]
    assert_equal "http_401", payload["status"]
    assert_match(/401/, payload["message"])
    assert_equal "http_401", connection.reload.last_check_status
  end

  test "catalog check handles network errors and unsupported probes" do
    sign_in
    connection = create_connection!

    network = Object.new
    network.define_singleton_method(:connection_check) do
      raise Translation::HttpClient::NetworkError
    end
    Translation::AdapterRouter.stub(:build, network) do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
    end
    assert_response :service_unavailable
    assert_equal "network_error", response.parsed_body["status"]

    unsupported = Object.new
    unsupported.define_singleton_method(:connection_check) do
      raise Translation::Adapters::BaseAdapter::UnsupportedProbe
    end
    Translation::AdapterRouter.stub(:build, unsupported) do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
    end
    assert_response :unprocessable_entity
    assert_equal "unsupported", response.parsed_body["status"]
  end

  test "catalog check requires recent administrator authentication before any provider call" do
    sign_in
    connection = create_connection!
    travel 11.minutes do
      post check_connection_admin_settings_inference_connection_path(connection), as: :json
      assert_redirected_to new_reauthentication_path
    end
  end

  test "opening the settings edit form requires recent authentication" do
    sign_in
    connection = create_connection!

    travel 11.minutes do
      get edit_admin_settings_inference_connection_path(connection)
      assert_redirected_to new_reauthentication_path
    end
  end
  test "model cards distinguish disabled models and keep the enable control prominent" do
    sign_in
    model = TranslationModel.ordered.first!
    model.update!(active: false)

    get admin_settings_inference_path
    assert_response :success
    assert_select ".app-model-card--disabled[data-model-id='#{model.id}']", count: 1 do
      assert_select ".app-model-status--disabled", text: "Disabled"
      assert_select "button.app-model-toggle--enable", text: "Enable model"
    end
    assert_select ".app-model-card--enabled", minimum: 1
  end

  test "already active deployment cannot create another version or audit entry" do
    sign_in
    connection = create_connection!
    model = TranslationModel.ordered.first!
    attributes = {
      translation_model_id: model.id,
      inference_connection_id: connection.id,
      remote_model_identifier: model.model_key
    }

    assert_difference ["ModelDeployment.count", "InferenceSettingEvent.count"], 1 do
      post admin_settings_model_deployments_path, params: attributes
    end
    assert_redirected_to admin_settings_inference_path
    first_deployment = model.active_deployment
    assert_equal 1, first_deployment.config_version

    get admin_settings_inference_path
    assert_response :success
    assert_select ".app-model-card[data-model-id='#{model.id}'] [data-controller='deployment-form'] form", count: 1 do
      assert_select "input[type='submit'][value='Deployment already active'][disabled]", count: 1
    end

    assert_no_difference ["ModelDeployment.count", "InferenceSettingEvent.count"] do
      post admin_settings_model_deployments_path, params: attributes
    end
    assert_redirected_to admin_settings_inference_path
    assert_equal first_deployment.id, model.reload.active_deployment.id

    assert_difference ["ModelDeployment.count", "InferenceSettingEvent.count"], 1 do
      post admin_settings_model_deployments_path,
        params: attributes.merge(remote_model_identifier: "alternate_remote_identifier")
    end
    assert_equal 2, model.reload.active_deployment.config_version
    assert_equal "alternate_remote_identifier", model.active_deployment.remote_model_identifier
    assert_equal false, first_deployment.reload.active?
  end

  test "settings audit names the model on both disable and enable events" do
    sign_in
    model = TranslationModel.ordered.first!
    patch admin_settings_translation_model_path(model), params: { active: "0" }
    assert_redirected_to admin_settings_inference_path
    assert_equal false, model.reload.active?

    assert_no_difference "InferenceSettingEvent.count" do
      patch admin_settings_translation_model_path(model), params: { active: "0" }
    end

    get admin_settings_inference_path
    assert_response :success
    assert_select ".app-model-card--disabled[data-model-id='#{model.id}']", count: 1
    assert_select ".app-audit-entry--model-disabled", text: /#{Regexp.escape(model.display_name)}.*#{Regexp.escape(model.model_key)}/, count: 1

    patch admin_settings_translation_model_path(model), params: { active: "1" }
    assert_redirected_to admin_settings_inference_path
    assert_equal true, model.reload.active?

    get admin_settings_inference_path
    assert_response :success
    assert_select ".app-audit-entry--model-enabled", text: /#{Regexp.escape(model.display_name)}.*#{Regexp.escape(model.model_key)}/, count: 1
    assert_select ".app-audit-entry--model-disabled", count: 1

    get admin_security_path
    assert_response :success
    assert_select ".app-audit-entry--model-enabled", count: 1
    assert_select ".app-audit-entry--model-disabled", count: 1

    recent = InferenceSettingEvent.where(translation_model: model).order(:id).last(2)
    assert_equal %w[model_disabled model_enabled], recent.map(&:action)
    assert_equal [model.model_key, model.model_key], recent.map { |event| event.changes_summary["model_key"] }
  end

end
