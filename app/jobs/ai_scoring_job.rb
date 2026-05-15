class AiScoringJob < ApplicationJob
  queue_as :ai_scoring

  DEFAULT_BATCH_COST_CAP_USD = 25.0
  CHUNK_SIZE = 25
  DEFAULT_CANDIDATE_LIMIT = 200  # score at most this many per run; override via ENV

  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  # Required keyword args:
  #   opening_id:      Integer
  #   batch_id:        String (UUID, generated client-side)
  #   requested_by_id: Integer (User id)
  #   provider_key:    String (e.g. 'chatgpt'), defaults to 'chatgpt'
  #   provider:        BaseAiProvider instance (optional for injection, mainly for tests)
  def perform(opening_id:, batch_id:, requested_by_id:, provider_key: 'chatgpt', provider: nil)
    log = AiScoringLog.find_or_create_by!(batch_id: batch_id) do |l|
      l.opening_id      = opening_id
      l.requested_by_id = requested_by_id
      l.provider        = provider_key
      l.model           = (provider || provider_for(provider_key)).model
      l.status          = 'pending'
    end

    # Acquire per-opening advisory lock before re-reading status so two concurrent
    # jobs with the same batch_id can't both slip through the pending check.
    should_process = false
    AiScoringLog.transaction do
      AiScoringLog.connection.execute(
        "SELECT pg_advisory_xact_lock(hashtext('ai_scoring:opening:#{opening_id.to_i}'))"
      )
      log.reload
      next if %w[processing completed cost_capped failed].include?(log.status)
      log.update!(status: 'processing', started_at: Time.current)
      should_process = true
    end

    return unless should_process

    process_batch(log, provider)
  rescue StandardError => e
    log&.update(status: 'failed', error_details: e.message, completed_at: Time.current)
    raise
  end

  private

  def process_batch(log, provider_instance = nil)
    opening   = Opening.find(log.opening_id)
    provider  = provider_instance || provider_for(log.provider)
    service   = AiScoringService.new(provider: provider, log: log)
    cap_usd   = batch_cost_cap

    candidates = candidates_for(opening)
    log.update!(total_candidates: candidates.size)

    candidates.each_slice(CHUNK_SIZE) do |chunk|
      chunk.each { |c| service.score(candidate: c, opening: opening) }
      log.reload
      if log.total_cost.to_f >= cap_usd
        log.update!(status: 'cost_capped', completed_at: Time.current)
        return
      end
    end

    log.update!(status: 'completed', completed_at: Time.current)
  end

  # Candidates with resumes, excluding any already scored for this opening.
  # Limits to DEFAULT_CANDIDATE_LIMIT per run so a single job stays practical
  # (~200 candidates ≈ 15 min, $0.03 with gpt-4o-mini).
  def candidates_for(opening)
    limit = ENV.fetch('AI_SCORING_CANDIDATE_LIMIT', DEFAULT_CANDIDATE_LIMIT).to_i
    already_scored = AiScore.valid_scores.where(opening_id: opening.id).select(:candidate_id)

    Candidate
      .where(opening_id: opening.id)
      .where.not(id: already_scored)
      .joins(:resume_attachment)
      .includes(resume_attachment: :blob)
      .order(:id)
      .limit(limit)
      .to_a
  end

  def provider_for(key)
    case key.to_s
    when 'chatgpt' then ChatgptProvider.new
    else raise ArgumentError, "Unknown provider: #{key.inspect}"
    end
  end

  def batch_cost_cap
    ENV.fetch('AI_SCORING_BATCH_COST_CAP_USD', DEFAULT_BATCH_COST_CAP_USD).to_f
  end
end
