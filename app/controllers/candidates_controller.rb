class CandidatesController < BaseController
  before_action :set_candidate, only: [:show, :edit, :update, :destroy]

  def index
    count_all = Candidate.unscoped.group(:bucket).count
    @recent_count = count_all["recent"] || 0
    @hot_count = count_all["hot"] || 0
    @pipeline_count = count_all["pipeline"] || 0
    @champions_count = count_all["champions"] || 0
    @joinings_count = count_all["joinings"] || 0
    @icebox_count = count_all["icebox"] || 0
    @archive_count = count_all["archive"] || 0
    @incomplete_count = count_all["incomplete"] || 0
    @alumni_count = count_all["alumni"] || 0
    @employees_count = count_all["employees"] || 0
    @contractors_count = count_all["contractors"] || 0
    @leads_count = count_all["leads"] || 0
    @nurture_count = count_all["nurture"] || 0

    @candidates_count = Candidate.count
  end

  def show
  end

  def update_bucket
    redirect_to candidates_path, notice: "Bucket was updated successfully"
  end

  def edit
    @roles = Role.all
    @openings = Opening.all
    @sources = Source.all
  end

  def update
    @candidate.update(candidate_params.except(:note))
    redirect_to candidate_timeline_path(@candidate), notice: "Candidate was updated successfully"
  end

  def destroy
  end

  def new
    @candidate = Candidate.new
    @roles = Role.all
    @openings = Opening.all
    @sources = Source.all
    @buckets = current_user.recruiter? ? Candidate.buckets.except(:pipeline) : Candidate.buckets
  end

  def create
    @candidate = Candidate.new(candidate_params.except(:note))
    @candidate.user = current_user
    @candidate.owner = current_user
    @candidate.next_recycle_on = DateTime.now
    if @candidate.save
      Event.new(eventable: @candidate, action: "add_candidate", action_for_context: "added new candidate", trackable: @candidate, user: current_user).save

      note = Note.new(notable: @candidate, user: current_user, body: candidate_params[:note])
      if note.save
        Event.new(eventable: @candidate, action: "add_note", action_for_context: "added a new note", trackable: note, user: current_user).save
      end

      redirect_to candidate_timeline_path(@candidate), notice: "New candidate was created successfully"
    else
      redirect_to new_candidate_path, alert: "Failed to add candidate. Please try again."
    end
  end

  def recent
    @pagy, @candidates = pagy(candidates_for_bucket(:recent), items: LIMIT)
  end

  def nurture
    @pagy, @candidates = pagy(candidates_for_bucket(:nurture), items: LIMIT)
  end

  def hot
    candidates = nil
    if current_user.admin?
      candidates = Candidate.unscoped.where(bucket: :hot).includes(:opening, :role, :owner, :user).order(bucket_updated_on: :desc)
    else
      candidates = Candidate.unscoped.where(bucket: :hot, owner: current_user).includes(:opening, :role, :owner, :user).order(bucket_updated_on: :desc)
    end
    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def pipeline
    @recruiters = User.owners
    candidates = nil
    if current_user.admin?
      if params[:recruiter].present?
        candidates = Candidate.unscoped.where(bucket: :pipeline, owner: params[:recruiter]).includes(:opening, :owner).order(bucket_updated_on: :desc)
      else
        candidates = Candidate.unscoped.where(bucket: :pipeline).includes(:opening, :owner).order(bucket_updated_on: :desc)
      end
    else
      candidates = Candidate.unscoped.where(bucket: :pipeline, owner: current_user).includes(:opening, :owner).order(bucket_updated_on: :desc)
    end
    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def champions
    candidates = nil
    candidates = Candidate.unscoped.where(bucket: :champions).includes(:opening, :owner).order(bucket_updated_on: :desc)

    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def joinings
    candidates = nil
    if current_user.admin?
      candidates = Candidate.unscoped.where(bucket: :joinings).includes(:opening, :role, :owner).order(joining_date: :asc)
    else
      candidates = Candidate.unscoped.where(bucket: :joinings, owner: current_user).includes(:opening, :role, :owner).order(joining_date: :asc)
    end

    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def icebox
    @pagy, @candidates = pagy(candidates_for_bucket(:icebox), items: LIMIT)
  end

  def archive
    candidates = nil
    if current_user.admin?
      candidates = Candidate.unscoped.where(bucket: :archive).includes(:opening, :owner).order(bucket_updated_on: :desc)
    else
      candidates = Candidate.unscoped.where(bucket: :archive, owner: current_user).includes(:opening, :owner).order(bucket_updated_on: :desc)
    end

    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def incomplete
    @pagy, @candidates = pagy(candidates_for_bucket(:incomplete), items: LIMIT)
  end

  def alumni
    @pagy, @candidates = pagy(candidates_for_bucket(:alumni), items: LIMIT)
  end

  def employees
    @pagy, @candidates = pagy(candidates_for_bucket(:employees), items: LIMIT)
  end

  def contractors
    @pagy, @candidates = pagy(candidates_for_bucket(:contractors), items: LIMIT)
  end

  def leads
    candidates = nil
    if current_user.admin?
      candidates = Candidate.unscoped.where(bucket: :leads).includes(:opening, :owner, :user).order(created_at: :desc)
    else
      candidates = Candidate.unscoped.where(bucket: :leads, owner: current_user).includes(:opening, :owner, :user).order(created_at: :desc)
    end

    @pagy, @candidates = pagy(candidates, items: LIMIT)
  end

  def settle_leads
    Candidate.where(bucket: :leads, status: :rejected_in_screening).each do |candidate|
      UpdateBucket.call(candidate, :archive, current_user, false)
    end
    redirect_to leads_candidates_path, notice: "Leads were settled successfully"
  end

  private

  def candidates_for_bucket(bucket)
    Candidate.unscoped.where(bucket: bucket).includes(:opening, :role, :user, :owner).order(bucket_updated_on: :desc)
  end

  def candidate_params
    params.require(:candidate).permit(:first_name, :last_name, :email, :phone, :location, :biography, :facebook, :role_id, :source_id, :opening_id, :linkedin, :github, :twitter, :portfolio, :website, :current_ctc, :expected_ctc, :current_company, :current_title, :notice_period, :experience, :birth_year, :highest_qualification, :bucket, :resume, :note, :owner_id)
  end

  def set_candidate
    @candidate ||= Candidate.find(params[:id])
  end
end
