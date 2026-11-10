module Admin
  class GlossaryEntriesController < BaseController
    before_action :set_entry, only: %i[edit update destroy]

    PAGE_SIZE = 20

    def index
      response.cache_control[:no_store] = true
      @source_filter = params[:source_language].to_s.strip.first(64)
      @target_filter = params[:target_language].to_s.strip.first(64)
      @active_filter = %w[true false].include?(params[:active]) ? params[:active] : ""
      scope = current_user.glossary_entries
      if @source_filter.present?
        scope = scope.where("source_language ILIKE ?", "%#{GlossaryEntry.sanitize_sql_like(@source_filter)}%")
      end
      if @target_filter.present?
        scope = scope.where("target_language ILIKE ?", "%#{GlossaryEntry.sanitize_sql_like(@target_filter)}%")
      end
      scope = scope.where(active: @active_filter == "true") if @active_filter.present?

      @total_count = scope.count
      @page_count = [(@total_count.to_f / PAGE_SIZE).ceil, 1].max
      raw_page = params[:page].to_s
      page = raw_page.match?(/\A\d{1,7}\z/) ? raw_page.to_i : 1
      @page = page.clamp(1, @page_count)
      @entries = scope.newest.limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE).to_a
      @filter_params = {
        source_language: @source_filter, target_language: @target_filter, active: @active_filter
      }.compact_blank
      @has_filters = @filter_params.present?
    end

    def new
      response.cache_control[:no_store] = true
      @entry = current_user.glossary_entries.new(active: true,
        source_language: params[:source_language].to_s.first(64),
        target_language: params[:target_language].to_s.first(64))
    end

    def create
      @entry = current_user.glossary_entries.new(glossary_params)
      if @entry.save
        redirect_to admin_glossary_entries_path, notice: t("glossary.created")
      else
        response.cache_control[:no_store] = true
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      response.cache_control[:no_store] = true
    end

    def update
      if @entry.update(glossary_params)
        redirect_to admin_glossary_entries_path, notice: t("glossary.updated")
      else
        response.cache_control[:no_store] = true
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @entry.destroy!
      redirect_to admin_glossary_entries_path, notice: t("glossary.deleted"), status: :see_other
    end

    private

    def set_entry
      @entry = current_user.glossary_entries.find(params[:id])
    end

    def glossary_params
      params.require(:glossary_entry).permit(
        :source_language, :target_language, :source_term, :target_term, :notes, :active
      )
    end
  end
end
