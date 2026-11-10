class TranslationModel < ApplicationRecord
  has_many :model_deployments, dependent: :restrict_with_exception
  has_many :translation_runs, dependent: :restrict_with_exception
  validates :model_key, presence: true, uniqueness: true
  validates :display_name, presence: true
  scope :ordered, -> { order(:position, :id) }
  def active_deployment = model_deployments.find_by(active: true)
end
