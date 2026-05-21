class Opening::AiScoresController < Opening::BaseController
  before_action :set_opening

  AVG_INPUT_TOKENS_PER_CANDIDATE  = 2_000
  AVG_OUTPUT_TOKENS_PER_CANDIDATE = 350

  # GET /openings/:opening_id/ai_scores
  def index
    authorize @opening, :show?
    @locations = Candidate
                   .joins(:ai_scores)
                   .where(ai_scores: { opening_id: @opening.id, is_valid: true })
                   .where(bucket: AiScoringJob::SCOREABLE_BUCKETS)
                   .reorder(nil)
                   .distinct
                   .pluck(:location)
                   .map(&:to_s)
                   .map(&:strip)
                   .reject(&:blank?)
                   .map(&:downcase)
                   .uniq
                   .sort
                   .map(&:titleize)

    scope = @opening.ai_scores.valid_scores.sorted_by_score
                    .joins(:candidate)
                    .where(candidates: { bucket: AiScoringJob::SCOREABLE_BUCKETS })

    locations = Array(params[:locations]).map(&:strip).reject(&:blank?)
    if locations.any?
      conditions = locations.map { "candidates.location ILIKE ?" }.join(" OR ")
      scope = scope.where(conditions, *locations.map { |l| "%#{l}%" })
    end

    if params[:date_from].present?
      from_date = Date.parse(params[:date_from]) rescue nil
      scope = scope.where("candidates.created_at >= ?", from_date.beginning_of_day) if from_date
    end

    if params[:date_to].present?
      to_date = Date.parse(params[:date_to]) rescue nil
      scope = scope.where("candidates.created_at <= ?", to_date.end_of_day) if to_date
    end

    if params[:query].present?
      q = "%#{params[:query].strip}%"
      scope = scope.where(
        "candidates.first_name || ' ' || candidates.last_name ILIKE :q OR candidates.email ILIKE :q OR candidates.location ILIKE :q",
        q: q
      )
    end

    page = [params[:page].to_i, 1].max

    # CTC is a free-text string column so it can't be filtered in SQL —
    # load all records only when that filter is active, then paginate in Ruby.
    if params[:min_ctc].present? || params[:max_ctc].present?
      min_ctc = params[:min_ctc].presence&.to_f
      max_ctc = params[:max_ctc].presence&.to_f
      all_scores = scope.preload(:candidate).to_a.select do |s|
        ctc = s.candidate.expected_ctc.to_s.gsub(/[^0-9.]/, "").to_f
        (min_ctc.nil? || ctc >= min_ctc) && (max_ctc.nil? || ctc <= max_ctc)
      end
      @pagy    = Pagy.new(count: all_scores.length, page: page, limit: 25)
      @ai_scores = all_scores.slice(@pagy.offset, @pagy.limit) || []
    else
      @pagy    = Pagy.new(count: scope.count, page: page, limit: 25)
      @ai_scores = scope.offset(@pagy.offset).limit(@pagy.limit).preload(:candidate).to_a
    end

    @latest_log = @opening.ai_scoring_logs.recent.first
    @cost_estimate_usd = estimate_cost_for_opening
  end

  # POST /openings/:opening_id/ai_scores
  # Enqueues a scoring batch. Idempotent on batch_id: callers may pass
  # a client-generated UUID; otherwise we generate one server-side.
  def create
    authorize @opening

    batch_id = params[:batch_id].presence || SecureRandom.uuid

    unless valid_batch_id?(batch_id)
      redirect_to opening_ai_scores_path(@opening), alert: 'Invalid batch id.'
      return
    end

    # Refuse to enqueue if a batch for this opening is already in flight.
    in_flight = @opening.ai_scoring_logs.where(status: %w[pending processing]).exists?
    if in_flight
      redirect_to opening_ai_scores_path(@opening), alert: 'A scoring run is already in progress for this opening.'
      return
    end

    AiScoringJob.perform_later(
      opening_id:      @opening.id,
      batch_id:        batch_id,
      requested_by_id: current_user.id,
      provider_key:    'chatgpt'
    )

    redirect_to opening_ai_scores_path(@opening),
      notice: 'AI scoring started. Refresh in a moment to see results.'
  end

  private

  # Defensive: only accept well-formed UUIDs to avoid weird DB content.
  def valid_batch_id?(value)
    value.is_a?(String) && value.match?(/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/)
  end

  # Rough estimate for the UI: count candidates × per-candidate baseline.
  # Real cost is recorded after the batch finishes.
  def estimate_cost_for_opening
    candidate_count = Candidate.where(opening_id: @opening.id, bucket: AiScoringJob::SCOREABLE_BUCKETS).count
    ChatgptProvider.new(api_key: 'estimate').estimate_cost(
      input_tokens:  candidate_count * AVG_INPUT_TOKENS_PER_CANDIDATE,
      output_tokens: candidate_count * AVG_OUTPUT_TOKENS_PER_CANDIDATE
    )
  end
end
