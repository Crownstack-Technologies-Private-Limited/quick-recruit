class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  has_one_attached :avatar

  enum :role, data: 0, recruiter: 1, interviewer: 2, admin: 3, recruiter_admin: 4, super_admin: 5

  validate :avatar_content_type
  validate :avatar_size

  scope :recruiters, -> { where(role: [:recruiter, :recruiter_admin], active: true).order(:first_name) }
  scope :admins, -> { where(role: :admin, active: true) }
  scope :data, -> { where(role: :data, active: true) }
  scope :owners, -> { where(role: [:admin, :recruiter, :recruiter_admin, :interviewer], active: true).order(:first_name) }
  scope :interviewers, -> { where(role: [:interviewer, :admin], active: true).order(:first_name) }

  def avatar_size
    if avatar.attached? && avatar.blob.byte_size > 1.megabytes
      errors.add(:avatar, "size should not be more than 1MB")
    end
  end

  def name
    first_name + " " + last_name
  end

  def admin_or_recruiter_admin?
    admin? or recruiter_admin? or super_admin?
  end

  def avatar_content_type
    if avatar.attached? && !avatar.content_type.in?(%w(image/jpeg image/png))
      errors.add(:avatar, "must be a JPEG or PNG")
    end
  end

  def self.bot
    find_by(email: "bot@crownstack.com")
  end

  def self.aashish
    find_by(email: "aashishdhawan@crownstack.com")
  end

  def openings
    Opening.where(owner: self, active: true)
  end
end
