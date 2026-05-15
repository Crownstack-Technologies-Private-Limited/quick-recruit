class AiScoringLog < ApplicationRecord
  belongs_to :opening
  belongs_to :requested_by, class_name: 'User'

  STATUSES = %w[pending processing completed failed cost_capped].freeze

  validates :batch_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :provider, :model, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
