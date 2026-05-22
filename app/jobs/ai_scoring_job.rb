class AiScoringJob < ApplicationJob
  queue_as :ai_scoring

  CHUNK_SIZE = 25
  SCOREABLE_BUCKETS = %w[recent hot pipeline leads inbound nurture].freeze

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
      quoted_key = AiScoringLog.connection.quote("ai_scoring:opening:#{opening_id.to_i}")
      AiScoringLog.connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{quoted_key}))")
      log.reload
      next if %w[processing completed failed paused cancelled].include?(log.status)
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
    opening  = Opening.find(log.opening_id)
    provider = provider_instance || provider_for(log.provider)

    JdExtractionService.ensure_extracted(opening: opening, provider: provider)

    service = AiScoringService.new(provider: provider, log: log)
    scope   = candidates_scope(opening)
    log.update!(total_candidates: scope.count)

    scope.find_in_batches(batch_size: CHUNK_SIZE) do |batch|
      break if log.reload.status.in?(%w[paused cancelled])
      batch.each { |c| service.score(candidate: c, opening: opening) }
      ActiveRecord::Base.connection.clear_query_cache
      GC.compact
    end

    log.update!(status: 'completed', completed_at: Time.current) unless log.reload.status.in?(%w[paused cancelled])
  ensure
    ActiveRecord::Base.connection.clear_query_cache
    GC.compact
  end

  def candidates_scope(opening)
    Candidate
      .where(opening_id: opening.id)
      .where(bucket: SCOREABLE_BUCKETS)
      .joins(:resume_attachment)
      .includes(resume_attachment: :blob)
      .order(:id)
  end

  def provider_for(key)
    case key.to_s
    when 'chatgpt' then ChatgptProvider.new
    else raise ArgumentError, "Unknown provider: #{key.inspect}"
    end
  end
end
