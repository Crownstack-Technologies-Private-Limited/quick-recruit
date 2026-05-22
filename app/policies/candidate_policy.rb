class CandidatePolicy < ApplicationPolicy
  def show?
    true
  end

  def update_bucket?
    user.admin_or_recruiter_admin? or user.data? or (user.recruiter? and (record.incomplete? or record.icebox?))
  end

  def update_status?
    return true unless user.interviewer?
  end

  def update_campaign?
    return true if (record.pipeline? and not user.interviewer?) or user.admin_or_recruiter_admin?
  end

  def update_joining?
    return true unless user.interviewer?
  end

  def update_recycle?
    return true unless user.interviewer?
  end

  def update_owner?
    user.admin_or_recruiter_admin?
  end

  def reject_and_icebox?
    return true unless user.interviewer?
  end

  def reject_and_archive?
    return true unless user.interviewer?
  end

  def toggle_recycle?
    return true unless user.interviewer?
  end
end
