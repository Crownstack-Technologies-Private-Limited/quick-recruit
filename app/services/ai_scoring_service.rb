class AiScoringService
  # Orchestrates scoring a single candidate against an opening.
  #
  # Returns a Result describing the outcome:
  #   - status:  :scored | :reused | :skipped | :failed
  #   - ai_score: AiScore | nil
  #   - reason:  String | nil  (set when :skipped or :failed)
  #   - tokens:  { input: Integer, output: Integer }   (zero when reused/skipped)
  #   - cost:    BigDecimal/Float                      (zero when reused/skipped)
  Result = Struct.new(:status, :ai_score, :reason, :tokens, :cost, keyword_init: true)

  def initialize(provider:, log: nil)
    @provider = provider     # an instance of BaseAiProvider subclass
    @log      = log          # optional AiScoringLog for accumulating totals
  end

  # Score one candidate. Idempotent w.r.t. existing valid score for the
  # same (candidate, opening, resume_hash, jd_hash) combination — returns
  # the existing record with status :reused.
  def score(candidate:, opening:)
    extraction = ResumeExtractor.extract(candidate)
    unless extraction.usable?
      record_log_failure(:extraction)
      return failed_result('resume_unusable', extraction.reason)
    end

    resume_hash = candidate.resume.attached? ? candidate.resume.blob.checksum : nil
    jd_hash     = PromptBuilder.jd_hash(opening)

    existing = find_existing_valid_score(candidate, opening, resume_hash, jd_hash)
    if existing
      record_log_reused
      return reused_result(existing)
    end

    prompt = PromptBuilder.build_scoring_prompt(
      candidate:   candidate,
      opening:     opening,
      resume_text: extraction.text
    )

    response = @provider.score(
      prompt:   prompt,
      metadata: { opening_id: opening.id, candidate_id: candidate.id, log_id: @log&.id }
    )

    ai_score = persist_score(
      candidate:   candidate,
      opening:     opening,
      response:    response,
      resume_hash: resume_hash,
      jd_hash:     jd_hash
    )

    record_log_success(response)
    scored_result(ai_score, response)
  rescue BaseAiProvider::ScoringError => e
    record_log_failure(:provider)
    failed_result('provider_error', e.message)
  end

  private

  def find_existing_valid_score(candidate, opening, resume_hash, jd_hash)
    AiScore.valid_scores.find_by(
      candidate_id:         candidate.id,
      opening_id:           opening.id,
      resume_version_hash:  resume_hash,
      jd_version_hash:      jd_hash
    )
  end

  def persist_score(candidate:, opening:, response:, resume_hash:, jd_hash:)
    AiScore.transaction do
      # Invalidate any prior valid score for this (candidate, opening) pair
      # so the partial unique index has room for the new row.
      AiScore.valid_scores
        .where(candidate_id: candidate.id, opening_id: opening.id)
        .update_all(
          is_valid:             false,
          invalidation_reason:  'superseded',
          invalidated_at:       Time.current
        )

      AiScore.create!(
        candidate:           candidate,
        opening:             opening,
        score:               response[:score],
        reasoning:           response[:reasoning],
        matched_skills:      response[:matched_skills] || {},
        gaps:                response[:gaps]           || {},
        strengths:           Array(response[:strengths]).join("\n"),
        concerns:            Array(response[:concerns]).join("\n"),
        provider:            @provider.provider_key,
        model:               @provider.model,
        input_tokens:        response[:tokens][:input],
        output_tokens:       response[:tokens][:output],
        cost:                @provider.estimate_cost(
          input_tokens:  response[:tokens][:input],
          output_tokens: response[:tokens][:output]
        ),
        resume_version_hash: resume_hash,
        jd_version_hash:     jd_hash,
        processed_at:        Time.current
      )
    end
  end

  def record_log_success(response)
    return unless @log
    cost = @provider.estimate_cost(
      input_tokens:  response[:tokens][:input],
      output_tokens: response[:tokens][:output]
    )
    @log.with_lock do
      @log.increment!(:successfully_scored)
      AiScoringLog.where(id: @log.id).update_all([
        'total_input_tokens = total_input_tokens + ?, ' \
        'total_output_tokens = total_output_tokens + ?, ' \
        'total_cost = total_cost + ?',
        response[:tokens][:input], response[:tokens][:output], cost
      ])
    end
  end

  def record_log_reused
    return unless @log
    @log.increment!(:successfully_scored)
  end

  # category: :extraction (unreadable resume) or :provider (AI provider error).
  # Bumps the grand total plus the matching cause-specific counter atomically.
  def record_log_failure(category)
    return unless @log
    sub_column = category == :provider ? 'provider_failed_count' : 'extraction_failed_count'
    AiScoringLog.where(id: @log.id).update_all(
      "failed_count = failed_count + 1, #{sub_column} = #{sub_column} + 1"
    )
  end

  def scored_result(ai_score, response)
    Result.new(
      status:   :scored,
      ai_score: ai_score,
      reason:   nil,
      tokens:   { input: response[:tokens][:input], output: response[:tokens][:output] },
      cost:     ai_score.cost
    )
  end

  def reused_result(ai_score)
    Result.new(
      status:   :reused,
      ai_score: ai_score,
      reason:   nil,
      tokens:   { input: 0, output: 0 },
      cost:     0
    )
  end

  def failed_result(status, reason)
    Result.new(
      status:   :failed,
      ai_score: nil,
      reason:   "#{status}:#{reason}",
      tokens:   { input: 0, output: 0 },
      cost:     0
    )
  end
end
