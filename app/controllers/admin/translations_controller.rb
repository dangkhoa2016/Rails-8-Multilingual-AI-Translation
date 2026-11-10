module Admin
  class TranslationsController < Admin::BaseController
    before_action :throttle_translation_creation!, only: :create,
      by: -> { current_user.id }, name: "per_admin"
    before_action :set_translation, only: %i[show progress refresh_status prefer export]
    HISTORY_PAGE_SIZE = 20
    HISTORY_STATUSES = %w[queued running completed partial_failed failed uncertain].freeze
    EXPORT_FORMATS = {
      "txt" => ["text/plain; charset=utf-8", "txt"],
      "md" => ["text/markdown; charset=utf-8", "md"],
      "json" => ["application/json; charset=utf-8", "json"]
    }.freeze

    def index
      response.cache_control[:no_store] = true
      @query = params[:q].to_s.strip.first(80)
      @status_filter = HISTORY_STATUSES.include?(params[:status]) ? params[:status] : ""
      @source_filter = params[:source_language].to_s.strip.first(64)
      @target_filter = params[:target_language].to_s.strip.first(64)
      @from_filter = valid_filter_date(params[:from])
      @to_filter = valid_filter_date(params[:to])

      scope = current_user.translation_requests
      if @query.present?
        like = "%#{TranslationRequest.sanitize_sql_like(@query)}%"
        if @query.delete_prefix("#").match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          scope = scope.where("source_language ILIKE :term OR target_language ILIKE :term OR id = :id",
            term: like, id: @query.delete_prefix("#"))
        else
          scope = scope.where("source_language ILIKE :term OR target_language ILIKE :term", term: like)
        end
      end
      scope = scope.where(status: @status_filter) if @status_filter.present?
      scope = scope.where("source_language ILIKE ?", "%#{TranslationRequest.sanitize_sql_like(@source_filter)}%") if @source_filter.present?
      scope = scope.where("target_language ILIKE ?", "%#{TranslationRequest.sanitize_sql_like(@target_filter)}%") if @target_filter.present?
      scope = scope.where(created_at: @from_filter.beginning_of_day..) if @from_filter
      scope = scope.where(created_at: ..@to_filter.end_of_day) if @to_filter

      @has_filters = [@query, @status_filter, @source_filter, @target_filter, params[:from].presence, params[:to].presence].any?(&:present?)
      @total_count = scope.count
      @page_count = [(@total_count.to_f / HISTORY_PAGE_SIZE).ceil, 1].max
      raw_page = params[:page].to_s
      page = raw_page.match?(/\A\d{1,7}\z/) ? raw_page.to_i : 1
      @page = page.clamp(1, @page_count)
      @translations = scope.order(created_at: :desc, id: :desc)
        .limit(HISTORY_PAGE_SIZE).offset((@page - 1) * HISTORY_PAGE_SIZE).to_a
      @filter_params = {
        q: @query, status: @status_filter,
        source_language: @source_filter, target_language: @target_filter,
        from: params[:from].to_s.first(10), to: params[:to].to_s.first(10)
      }.compact_blank
    end

    def new
      @models = TranslationModel.ordered.includes(model_deployments: :inference_connection)
      @client_request_key = SecureRandom.uuid
      @glossary_count = current_user.glossary_entries.where(active: true).count
    end

    def create
      @translation = Translation::DispatchPlanner.call(user: current_user,
        source_text: params[:source_text], source_language: params[:source_language],
        target_language: params[:target_language], preserve_formatting: params[:preserve_formatting] == "1",
        model_ids: params[:model_ids], client_request_key: params[:client_request_key],
        cost_approved: params[:cost_approved] == "1", use_glossary: params[:use_glossary] == "1",
        ui_locale: I18n.locale.to_s)
      redirect_to admin_translation_path(@translation), notice: t("notices.translation_recorded")
    rescue Translation::DispatchPlanner::InvalidSelection => e
      redirect_to new_admin_translation_path, alert: e.message
    end

    def show
      response.cache_control[:no_store] = true
      @runs = @translation.latest_runs
    end

    def export
      response.cache_control[:no_store] = true
      file_format = params[:file_format].to_s
      type, extension = EXPORT_FORMATS[file_format]
      raise ActionController::RoutingError, "Not Found" unless type

      document = Translation::ExportDocument.new(@translation, @translation.latest_runs)
      send_data document.render(file_format), type: type,
        filename: "translation-#{@translation.id}.#{extension}", disposition: "attachment"
    end

    def progress
      @runs = @translation.latest_runs
      finished = @runs.all?(&:terminal?)
      # This endpoint can contain private translation text and must not be cached.
      response.cache_control[:no_store] = true
      response.headers["X-Translation-Terminal"] = finished.to_s

      # Rendered cards contain random CSRF masking, so their HTTP ETag is not
      # a stable progress version. Use a deterministic, data-only header for
      # conditional polling; 204 avoids replacing unchanged UI.
      version = [@translation.cache_key_with_version,
        @runs.map { |run| [run.id, run.cache_key_with_version, run.translation_dispatch&.cache_key_with_version] }]
      progress_version = Digest::SHA256.hexdigest(version.to_json)
      response.headers["X-Progress-Version"] = progress_version
      if request.headers["X-Progress-Version"] == progress_version
        head :no_content
        return
      end

      render turbo_stream: [
        turbo_stream.replace("translation_header_status_#{@translation.id}",
          partial: "admin/translations/status_line", locals: { translation: @translation }),
        turbo_stream.replace("translation_progress_#{@translation.id}",
          partial: "admin/translations/progress", locals: { translation: @translation, runs: @runs }),
        turbo_stream.replace("translation_results_#{@translation.id}",
          partial: "admin/translations/results", locals: { translation: @translation, runs: @runs })
      ]
    end

    def refresh_status
      throttle_admin_operation!(name: "status_refresh", limit: 12, within: 1.minute)
      # Only enqueue safe GET polling. Never issue a new provider POST on page refresh.
      @translation.translation_dispatches.where(status: "accepted").find_each do |dispatch|
        PollTranslationDispatchJob.perform_later(dispatch.id)
      end
      redirect_to admin_translation_path(@translation), notice: t("notices.status_scheduled")
    end

    def prefer
      run = @translation.translation_runs.find_by!(translation_model_id: params[:model_id], status: "completed")
      previous_model_id = @translation.preferred_model_id
      @translation.update!(preferred_model: run.translation_model)

      respond_to do |format|
        format.turbo_stream do
          @runs = @translation.latest_runs
          changed_runs = @runs.select do |item|
            [previous_model_id, @translation.preferred_model_id].include?(item.translation_model_id)
          end

          # Replace only the selected-results preview and the affected cards.
          # The original text, the other model cards and the scroll position stay intact.
          render turbo_stream: [
            turbo_stream.replace("translation_source_#{@translation.id}",
              partial: "admin/translations/source_panel",
              locals: { translation: @translation, runs: @runs, expanded: true }),
            *changed_runs.map do |item|
              turbo_stream.replace(helpers.dom_id(item),
                partial: "admin/translations/run_card", locals: { run: item })
            end
          ]
        end
        format.html do
          redirect_to admin_translation_path(@translation), notice: t("notices.preferred_updated")
        end
      end
    end

    private

    def valid_filter_date(value)
      return if value.blank?
      return unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(value)
    rescue Date::Error, ArgumentError
      nil
    end

    def throttle_translation_creation!
      return if LoginThrottle.consume!("translation_create", current_user.id.to_s, limit: 8, window: 1.minute)
      response.headers["Retry-After"] = "60"
      raise ActionController::TooManyRequests
    end

    def set_translation
      @translation = current_user.translation_requests.find(params[:id])
      authorize @translation, "#{action_name}?"
    end
  end
end
