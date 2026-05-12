class Candidate < ApplicationRecord
  belongs_to :role
  belongs_to :source
  belongs_to :opening
  belongs_to :user
  belongs_to :owner, class_name: "User", foreign_key: "owner_id", optional: true
  has_one_attached :resume, dependent: :destroy

  has_many :notes, as: :notable, dependent: :destroy
  has_many :events, as: :eventable, dependent: :destroy
  has_many :emails, dependent: :destroy

  has_and_belongs_to_many :campaigns

  normalizes :email, with: ->email { email.downcase.strip }

  validates :email, uniqueness: true
  validate :correct_resume_mime_type
  validate :resume_file_size

  enum :bucket, recent: 0, hot: 1, pipeline: 2, champions: 3, joinings: 4, icebox: 5, archive: 6, incomplete: 7, alumni: 8, employees: 9, contractors: 10, leads: 11, nurture: 12, inbound: 13

  enum :status, [:waiting_for_evaluation, :interview_to_be_scheduled, :first_round_scheduled, :second_round_scheduled, :hr_round_scheduled, :offer_to_be_made, :offer_made, :offer_accepted, :joined, :on_hold, :no_show, :not_contactable, :follow_up_needed, :not_interested, :rejected_in_screening, :rejected_in_first_round, :rejected_in_second_round, :rejected_in_hr_round, :offer_withdrawn, :offer_declined, :unqualified, :other, :irrelevant, :incomplete_profile, :moved_on]

  default_scope { order(created_at: :desc) }

  def name
    first_name + " " + last_name
  end

  def age
    if birth_year.nil?
      "-"
    else
      (Date.today.year - birth_year).to_formatted_s + " years"
    end
  end

  def self.query(params, includes = nil)
    return [] if params.empty?
    CandidateQuery.new(self.unscoped.includes(:role, :opening, :user), params).filter
  end

  def self.new_candidates_query(params, includes = nil)
    return [] if params.empty?
    NewCandidatesQuery.new(self.unscoped.includes(:opening, :user), params).filter
  end

  def self.update_candidates_query(params, includes = nil)
    return [] if params.empty?
    UpdateCandidatesQuery.new(self.unscoped.includes(:opening, :user, :owner), params).filter
  end

  def self.bucket_report_query(params, includes = nil)
    return [] if params.empty?
    BucketReportQuery.new(self.unscoped.includes(:opening, :user, :owner), params).filter
  end
  
  def status_color
  end

  def being_recycled?
    Recycle.where(candidate_id: id).exists?
  end

  def recycled?
    recycle = Recycle.where(candidate_id: id).last

    recycle.present? && recycle.recycled?
  end

  private

  def correct_resume_mime_type
    if resume.attached? && !resume.content_type.in?(%w(application/pdf))
      errors.add(:resume, "Must be a PDF file")
    end
  end

  def resume_file_size
    if resume.attached? && resume.blob.byte_size > 5.megabytes
      errors.add(:resume, "Size should not be more than 5MB")
    end
  end
end
