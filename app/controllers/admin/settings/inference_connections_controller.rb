module Admin
  module Settings
    class InferenceConnectionsController < Admin::BaseController
      before_action :require_recent_authentication!, only: %i[new edit create update check_connection]
      before_action :set_connection, only: %i[edit update check_connection]
      before_action :limit_settings_mutations!, only: %i[create update check_connection]

      def index
        @connections = InferenceConnection.order(:name)
      end

      def new
        @connection = InferenceConnection.new(provider: "other", adapter_key: "translation_gateway_v1", auth_type: "bearer")
      end

      def create
        @connection = InferenceConnection.new(connection_params.except(:api_token))
        @connection.api_token = connection_params[:api_token] if connection_params[:api_token].present?
        if @connection.save
          audit!("connection_created", connection: @connection)
          redirect_to admin_settings_inference_path, notice: t("notices.connection_saved")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        attributes = connection_params.except(:api_token)
        # Blank token explicitly preserves the encrypted previous value.
        attributes[:api_token] = connection_params[:api_token] if connection_params[:api_token].present?
        if @connection.update(attributes)
          audit!("connection_updated", connection: @connection)
          redirect_to admin_settings_inference_path, notice: t("notices.connection_updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def check_connection
        # A deliberate non-inference GET; even this request can wake a sleeping host.
        catalog = Translation::AdapterRouter.build(connection: @connection).connection_check
        @connection.update_columns(last_checked_at: Time.current, last_check_status: "reachable")
        models = catalog_model_identifiers(catalog)
        respond_to_probe(ok: true, status: "reachable", message: t("notices.probe_succeeded"),
          models: models, model_count: catalog_model_count(catalog))
      rescue Translation::Adapters::BaseAdapter::UnsupportedProbe
        @connection.update_columns(last_checked_at: Time.current, last_check_status: "unsupported")
        respond_to_probe(ok: false, status: "unsupported", message: t("notices.probe_not_supported"),
          http_status: :unprocessable_entity)
      rescue Translation::HttpClient::HttpError => e
        @connection.update_columns(last_checked_at: Time.current, last_check_status: "http_#{e.status}")
        respond_to_probe(ok: false, status: "http_#{e.status}", message: t("notices.probe_http", status: e.status),
          http_status: :bad_gateway)
      rescue Translation::HttpClient::NetworkError, Translation::SafeEndpoint::Invalid
        @connection.update_columns(last_checked_at: Time.current, last_check_status: "network_error")
        respond_to_probe(ok: false, status: "network_error", message: t("notices.probe_failed"),
          http_status: :service_unavailable)
      end

      private

      def respond_to_probe(ok:, status:, message:, http_status: :ok, models: [], model_count: nil)
        payload = {
          ok: ok, status: status, message: message,
          checked_at: @connection.last_checked_at&.iso8601,
          checked_at_label: @connection.last_checked_at && l(@connection.last_checked_at, format: :short),
          models: models, model_count: model_count
        }

        respond_to do |format|
          format.json { render json: payload, status: http_status }
          format.html do
            if ok
              redirect_to admin_settings_inference_path, notice: message
            else
              redirect_to admin_settings_inference_path, alert: message
            end
          end
        end
      end

      def catalog_entries(catalog)
        entries = if catalog.is_a?(Array)
          catalog
        elsif catalog.is_a?(Hash)
          catalog["models"] || catalog["data"]
        end
        entries.is_a?(Array) ? entries : nil
      end

      def catalog_model_count(catalog)
        catalog_entries(catalog)&.length
      end

      def catalog_model_identifiers(catalog)
        entries = catalog_entries(catalog)
        return [] unless entries

        entries.first(30).filter_map do |entry|
          identifier = if entry.is_a?(String)
            entry
          elsif entry.is_a?(Hash)
            entry["key"] || entry["id"] || entry["model"] || entry["name"]
          end
          identifier.strip[0, 120] if identifier.is_a?(String) && identifier.strip.present?
        end.uniq.first(12)
      end

      def limit_settings_mutations!
        throttle_admin_operation!(name: "settings", limit: 20, within: 10.minutes)
        if action_name == "check_connection"
          throttle_admin_operation!(name: "probe", limit: 4, within: 1.minute)
        end
      end

      def set_connection
        @connection = InferenceConnection.find(params[:id])
      end

      def connection_params
        params.require(:inference_connection).permit(:name, :provider, :adapter_key, :base_url, :auth_type, :api_token, :enabled)
      end

      def audit!(action, connection:)
        InferenceSettingEvent.create!(user: current_user, inference_connection: connection,
          action: action, changes_summary: { provider: connection.provider, adapter_key: connection.adapter_key,
            enabled: connection.enabled? })
      end
    end
  end
end
