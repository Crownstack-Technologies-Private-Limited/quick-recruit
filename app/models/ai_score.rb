class AiScore < ApplicationRecord
  belongs_to :candidate
  belongs_to :opening

  validates :score, presence: true, numericality: { in: 0..100, only_integer: true }
  validates :reasoning, presence: true
  validates :provider, presence: true
  validates :model, presence: true

  scope :valid_scores,    -> { where(is_valid: true).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :invalid_scores,  -> { where(is_valid: false) }
  scope :sorted_by_score, -> { order(score: :desc) }

  before_validation :set_expiry, on: :create

  def still_valid?
    is_valid && !expired?
  end

  def expired?
    return false if expires_at.blank?
    Time.current >= expires_at
  end

  private

  def set_expiry
    self.expires_at ||= (processed_at || Time.current) + expiry_days.days
  end

  def expiry_days
    ENV.fetch('AI_SCORE_EXPIRY_DAYS', 90).to_i
  end
end
