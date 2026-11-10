class InferenceSettingEvent < ApplicationRecord
  belongs_to :user
  belongs_to :inference_connection, optional: true
  belongs_to :translation_model, optional: true
  validates :action, presence: true
end
