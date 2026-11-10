class GlossaryEntry < ApplicationRecord
  belongs_to :user
  encrypts :source_term, :target_term, :notes

  validates :source_language, :target_language, presence: true, length: { maximum: 64 }
  validates :source_term, :target_term, presence: true, length: { maximum: 120 }
  validates :notes, length: { maximum: 320 }, allow_blank: true
  validate :language_labels_valid
  validate :terms_are_plain_text

  scope :newest, -> { order(created_at: :desc, id: :desc) }

  private

  def language_labels_valid
    [[:source_language, source_language], [:target_language, target_language]].each do |field, label|
      next if label.blank?
      unless label.match?(/[\p{L}]/) && !label.match?(/[\p{Cc}\p{Cf}]/)
        errors.add(field, :invalid)
      end
    end
  end

  def terms_are_plain_text
    [[:source_term, source_term], [:target_term, target_term], [:notes, notes]].each do |field, value|
      next if value.blank?
      errors.add(field, :invalid) if value.match?(/[\p{Cc}&&[^\n\t]]/)
    end
  end
end
