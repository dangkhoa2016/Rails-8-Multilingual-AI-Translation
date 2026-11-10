class ReconcileTranslationDispatchesJob < ApplicationJob
  queue_as :default

  # A crashed worker may leave an unacknowledged provider POST in "submitting".
  # We cannot know whether the provider started paid inference: never re-POST.
  STALE_SUBMISSION_AFTER = 10.minutes
  STALE_POLL_AFTER = 5.minutes
  MAX_PER_SWEEP = 50

  def perform
    mark_unknown_submissions
    resume_safe_polling
  end

  private

  def mark_unknown_submissions
    cutoff = Time.current - STALE_SUBMISSION_AFTER
    stale_ids = TranslationDispatch.where(status: "submitting")
      .where("started_at IS NOT NULL AND started_at < ?", cutoff)
      .order(:started_at, :id).limit(MAX_PER_SWEEP).pluck(:id)

    stale_ids.each do |id|
      dispatch = TranslationDispatch.find_by(id: id)
      next unless dispatch

      request = nil
      dispatch.with_lock do
        next unless dispatch.status == "submitting" && dispatch.started_at && dispatch.started_at < cutoff

        dispatch.update!(status: "uncertain")
        dispatch.translation_runs.where(status: %w[queued running]).find_each do |run|
          run.update!(status: "uncertain", error_code: "DISPATCH_OUTCOME_UNKNOWN",
            last_seen_at: Time.current)
        end
        request = dispatch.translation_request
      end
      request&.refresh_status!
    end
  end

  def resume_safe_polling
    # A status GET can wake certain sleeping inference hosts. Make resuming
    # orphaned polls explicitly opt-in; stale POSTs are still flagged safely.
    return unless ENV["TRANSLATION_RECOVERY_POLLING_ENABLED"] == "1"

    cutoff = Time.current - STALE_POLL_AFTER
    stale_ids = TranslationDispatch.where(status: "accepted")
      .where("COALESCE(last_polled_at, updated_at) < ?", cutoff)
      .order(:updated_at, :id).limit(MAX_PER_SWEEP).pluck(:id)

    stale_ids.each do |id|
      # Even if a previously scheduled poll is still pending, additional
      # read-only GET is safe. Never enqueue SubmitTranslationDispatchJob here.
      PollTranslationDispatchJob.perform_later(id) if TranslationDispatch.where(id: id, status: "accepted").exists?
    end
  end
end
