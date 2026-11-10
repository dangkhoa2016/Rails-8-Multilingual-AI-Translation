class TranslationDispatch < ApplicationRecord
  belongs_to :translation_request
  belongs_to :inference_connection
  has_many :translation_runs, dependent: :restrict_with_exception
  validates :idempotency_key, presence: true, uniqueness: true
  validates :provider_snapshot, :adapter_key_snapshot, :base_url_snapshot, :remote_model_identifier_snapshot, presence: true
  def terminal? = %w[resolved failed uncertain].include?(status)
end
