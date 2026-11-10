class ModelDeployment < ApplicationRecord
  belongs_to :translation_model
  belongs_to :inference_connection
  has_many :translation_runs, dependent: :restrict_with_exception
  validates :remote_model_identifier, presence: true
  validates :config_version, numericality: { greater_than: 0, only_integer: true }
  validate :enabled_connection_when_active
  def enabled_connection_when_active
    errors.add(:inference_connection, "must be enabled") if active? && !inference_connection&.enabled?
  end
end
