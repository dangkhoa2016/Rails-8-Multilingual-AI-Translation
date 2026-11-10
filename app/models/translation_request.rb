class TranslationRequest < ApplicationRecord
  encrypts :source_text, :glossary_snapshot
  belongs_to :user
  belongs_to :preferred_model, class_name: "TranslationModel", optional: true
  has_many :translation_dispatches, dependent: :restrict_with_exception
  has_many :translation_runs, dependent: :restrict_with_exception
  validates :client_request_key, presence: true, uniqueness: { scope: :user_id }
  validates :source_text, presence: true
  validates :ui_locale, inclusion: { in: %w[en vi] }
  validates :source_language, :target_language, presence: true
  validate :different_languages
  after_update_commit :broadcast_progress_hint, if: :saved_change_to_status?

  def latest_runs
    translation_runs.order(:attempt_no, :created_at).group_by(&:translation_model_id).values.map(&:last)
  end

  def glossary_terms
    return [] unless use_glossary? && glossary_snapshot.present?
    JSON.parse(glossary_snapshot)
  rescue JSON::ParserError
    []
  end

  def refresh_status!
    states = latest_runs.map(&:status)
    state = if states.all?("completed")
      "completed"
    elsif states.all? { |s| %w[completed failed].include?(s) }
      states.include?("completed") ? "partial_failed" : "failed"
    elsif states.any? { |s| s.include?("uncertain") }
      "uncertain"
    elsif states.any?("running")
      "running"
    else
      "queued"
    end
    update!(status: state, resolved_at: %w[completed partial_failed failed].include?(state) ? Time.current : nil)
  end

  private

  def broadcast_progress_hint
    broadcast_replace_to self,
      target: "translation_signal_#{id}",
      partial: "admin/translations/signal",
      locals: { translation: self }
  end

  def different_languages
    return if source_language.blank? || target_language.blank?
    if source_language.strip.downcase(:fold) == target_language.strip.downcase(:fold)
      errors.add(:target_language, I18n.t("errors.target_must_differ"))
    end
  end
end
