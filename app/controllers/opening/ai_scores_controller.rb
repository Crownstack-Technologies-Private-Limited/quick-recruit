class Opening::AiScoresController < Opening::BaseController
  before_action :set_opening

  # GET /openings/:opening_id/ai_scores
  # Lists valid AI scores for the opening, sorted by score desc.
  def index
    @ai_scores = @opening.ai_scores
                   .valid_scores
                   .sorted_by_score
                   .includes(:candidate)
    @latest_log = @opening.ai_scoring_logs.recent.first
    @cost_estimate_usd = estimate_cost_for_opening
  end

  # GET /openings/:opening_id/ai_scores/:id
  # Detail view (used by the candidate detail modal).
  def show
    @ai_score = @opening.ai_scores.find(params[:id])
    @candidate = @ai_score.candidate
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
    candidate_count = Candidate.where(opening_id: @opening.id).count
    candidate_count * ChatgptProvider::INPUT_PRICE_PER_1M / 1_000_000.0 * 2_000 +
      candidate_count * ChatgptProvider::OUTPUT_PRICE_PER_1M / 1_000_000.0 * 350
  end
end
