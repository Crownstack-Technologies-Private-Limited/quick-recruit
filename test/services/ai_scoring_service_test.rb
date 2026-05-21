require 'test_helper'

class AiScoringServiceTest < ActiveSupport::TestCase
  # Fake provider for testing
  class FakeProvider < BaseAiProvider
    PROVIDER_KEY = 'fake'
    MODEL        = 'fake-1'

    attr_accessor :next_response, :next_error, :call_count

    def initialize(api_key: nil)
      super
      @call_count = 0
    end

    def score(prompt:)
      @call_count += 1
      raise next_error if next_error
      next_response
    end

    def estimate_cost(input_tokens:, output_tokens:)
      (input_tokens + output_tokens) * 0.000001
    end

    private

    def api_key_from_env
      'fake'
    end
  end

  def setup
    @candidate = candidates(:jane_smith)  # Use jane_smith to avoid fixture conflicts
    @opening = openings(:mobile_opening)  # Use mobile_opening to avoid fixture conflicts
    @provider = FakeProvider.new
    @service = AiScoringService.new(provider: @provider)
    @original_extract_method = ResumeExtractor.method(:extract)
  end

  def teardown
    # Restore the original extract method
    if @original_extract_method.is_a?(Method)
      ResumeExtractor.define_singleton_method(:extract, @original_extract_method)
    end
  end

  # Happy path: candidate with attached resume + valid response → :scored, AiScore persisted
  def test_score_happy_path
    attach_resume(@candidate)

    mock_extraction(@candidate, usable: true)

    @provider.next_response = {
      score: 85,
      reasoning: 'Good fit',
      matched_skills: { 'React' => 90, 'Node.js' => 80 },
      gaps: { 'Kubernetes' => 'No experience mentioned' },
      strengths: ['Strong technical background'],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :scored, result.status
    assert_not_nil result.ai_score
    assert_nil result.reason
    assert_equal 2000, result.tokens[:input]
    assert_equal 350, result.tokens[:output]

    ai_score = result.ai_score
    assert_equal 85, ai_score.score
    assert_equal 'Good fit', ai_score.reasoning
    assert_equal 'fake', ai_score.provider
    assert_equal 'fake-1', ai_score.model
    assert_equal 2000, ai_score.input_tokens
    assert_equal 350, ai_score.output_tokens
    assert ai_score.cost > 0
    assert_equal true, ai_score.is_valid
    assert_nil ai_score.invalidation_reason
    assert ai_score.processed_at.present?
  end

  # Dedup: when a valid AiScore already exists → :reused, no new record, provider not called
  def test_score_dedup_existing_valid_score
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    resume_hash = @candidate.resume.blob.checksum
    jd_hash = PromptBuilder.jd_hash(@opening)

    # Create existing valid score
    existing_score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: 'Good fit',
      provider: 'test',
      model: 'test-1',
      is_valid: true,
      resume_version_hash: resume_hash,
      jd_version_hash: jd_hash,
      processed_at: Time.current
    )

    @provider.next_response = {
      score: 90,
      reasoning: 'New score',
      matched_skills: {},
      gaps: {},
      strengths: [],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :reused, result.status
    assert_equal existing_score.id, result.ai_score.id
    assert_nil result.reason
    assert_equal 0, result.tokens[:input]
    assert_equal 0, result.tokens[:output]
    assert_equal 0, result.cost
    assert_equal 0, @provider.call_count, "Provider should not be called on dedup"
  end

  # Supersession: existing valid score with different jd_hash → new score created, old marked invalid
  def test_score_supersession_jd_changed
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    resume_hash = @candidate.resume.blob.checksum

    # Create existing valid score with old jd_hash
    old_score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 75,
      reasoning: 'Older score',
      provider: 'test',
      model: 'test-1',
      is_valid: true,
      resume_version_hash: resume_hash,
      jd_version_hash: 'old_hash',
      processed_at: Time.current
    )

    @provider.next_response = {
      score: 88,
      reasoning: 'New score for new JD',
      matched_skills: { 'Python' => 85 },
      gaps: {},
      strengths: ['Great Python skills'],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :scored, result.status
    assert_not_equal old_score.id, result.ai_score.id
    assert_equal 88, result.ai_score.score

    # Old score should be invalidated
    old_score.reload
    assert_equal false, old_score.is_valid
    assert_equal 'superseded', old_score.invalidation_reason
    assert old_score.invalidated_at.present?
  end

  # Provider error: provider raises ScoringError → :failed, no AiScore created
  def test_score_provider_error
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    error = BaseAiProvider::ScoringError.new('API rate limit exceeded')
    @provider.next_error = error

    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :failed, result.status
    assert_nil result.ai_score
    assert_match /provider_error/, result.reason
    assert_match /API rate limit exceeded/, result.reason
    assert_equal 0, result.tokens[:input]
    assert_equal 0, result.tokens[:output]
    assert_equal 0, result.cost
  end

  # Resume missing: candidate without attached resume → :failed, provider NOT called
  def test_score_resume_missing
    # Don't attach resume
    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :failed, result.status
    assert_nil result.ai_score
    assert_match /resume_unusable/, result.reason
    assert_match /no_resume_attached/, result.reason
    assert_equal 0, @provider.call_count, "Provider should not be called when resume missing"
  end

  # Resume too short: stub extraction with usable: false → :failed
  def test_score_resume_too_short
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: false, reason: 'extracted_text_too_short')

    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :failed, result.status
    assert_nil result.ai_score
    assert_match /resume_unusable/, result.reason
    assert_match /extracted_text_too_short/, result.reason
    assert_equal 0, @provider.call_count
  end

  # Log accumulation: success increments counters, failure increments failed_count
  def test_score_log_accumulation_success
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)
    log = ai_scoring_logs(:mobile_opening_log)

    @provider.next_response = {
      score: 75,
      reasoning: 'Okay fit',
      matched_skills: {},
      gaps: {},
      strengths: [],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    service_with_log = AiScoringService.new(provider: @provider, log: log)
    result = service_with_log.score(candidate: @candidate, opening: @opening)

    assert_equal :scored, result.status

    log.reload
    assert_equal 1, log.successfully_scored
    assert_equal 2000, log.total_input_tokens
    assert_equal 350, log.total_output_tokens
    assert log.total_cost > 0
  end

  # Provider error increments failed_count and provider_failed_count
  def test_score_log_accumulation_failure
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)
    log = ai_scoring_logs(:mobile_opening_log)
    log.update!(failed_count: 0, extraction_failed_count: 0, provider_failed_count: 0)

    error = BaseAiProvider::ScoringError.new('API error')
    @provider.next_error = error

    service_with_log = AiScoringService.new(provider: @provider, log: log)
    result = service_with_log.score(candidate: @candidate, opening: @opening)

    assert_equal :failed, result.status

    log.reload
    assert_equal 1, log.failed_count
    assert_equal 1, log.provider_failed_count
    assert_equal 0, log.extraction_failed_count
  end

  # Unreadable resume increments failed_count and extraction_failed_count
  def test_score_log_accumulation_extraction_failure
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: false, reason: 'extracted_text_too_short')
    log = ai_scoring_logs(:mobile_opening_log)
    log.update!(failed_count: 0, extraction_failed_count: 0, provider_failed_count: 0)

    service_with_log = AiScoringService.new(provider: @provider, log: log)
    result = service_with_log.score(candidate: @candidate, opening: @opening)

    assert_equal :failed, result.status

    log.reload
    assert_equal 1, log.failed_count
    assert_equal 1, log.extraction_failed_count
    assert_equal 0, log.provider_failed_count
  end

  # Transaction integrity: verify that both old-score invalidation and new-score creation happen together
  def test_score_transaction_wraps_invalidate_and_create
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    # Create old valid score
    old_score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 70,
      reasoning: 'Old',
      provider: 'test',
      model: 'test-1',
      is_valid: true,
      processed_at: Time.current
    )

    @provider.next_response = {
      score: 92,
      reasoning: 'Better fit',
      matched_skills: {},
      gaps: {},
      strengths: [],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    # Verify both invalidation and creation happen
    result = @service.score(candidate: @candidate, opening: @opening)

    assert_equal :scored, result.status
    assert_not_nil result.ai_score

    # Old score should be invalidated
    old_score.reload
    assert_equal false, old_score.is_valid
    assert_equal 'superseded', old_score.invalidation_reason
    assert old_score.invalidated_at.present?

    # New score should exist and be valid
    new_score = result.ai_score
    assert_equal 92, new_score.score
    assert_equal true, new_score.is_valid
    assert_nil new_score.invalidation_reason
  end

  # Matched skills and gaps are properly persisted from response
  def test_score_matched_skills_and_gaps_persisted
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    matched_skills = { 'React' => 95, 'TypeScript' => 85 }
    gaps = { 'Kubernetes' => 'No experience', 'GraphQL' => 'Not mentioned' }

    @provider.next_response = {
      score: 82,
      reasoning: 'Strong frontend skills, missing some DevOps',
      matched_skills: matched_skills,
      gaps: gaps,
      strengths: ['Excellent React expertise'],
      concerns: ['Limited Kubernetes exposure'],
      tokens: { input: 2000, output: 350 }
    }

    result = @service.score(candidate: @candidate, opening: @opening)
    ai_score = result.ai_score

    assert_equal matched_skills, ai_score.matched_skills
    assert_equal gaps, ai_score.gaps
    assert_equal 'Excellent React expertise', ai_score.strengths
    assert_equal 'Limited Kubernetes exposure', ai_score.concerns
  end

  # Resume and JD hashes are correctly stored for dedup
  def test_score_hashes_stored_correctly
    attach_resume(@candidate)
    mock_extraction(@candidate, usable: true)

    @provider.next_response = {
      score: 78,
      reasoning: 'Good match',
      matched_skills: {},
      gaps: {},
      strengths: [],
      concerns: [],
      tokens: { input: 2000, output: 350 }
    }

    result = @service.score(candidate: @candidate, opening: @opening)
    ai_score = result.ai_score

    expected_resume_hash = @candidate.resume.blob.checksum
    expected_jd_hash = PromptBuilder.jd_hash(@opening)

    assert_equal expected_resume_hash, ai_score.resume_version_hash
    assert_equal expected_jd_hash, ai_score.jd_version_hash
  end

  private

  def attach_resume(candidate)
    candidate.resume.attach(
      io: StringIO.new('%PDF-1.4 fake content for tests'),
      filename: 'resume.pdf',
      content_type: 'application/pdf'
    )
  end

  def mock_extraction(candidate, usable:, reason: nil)
    result = ResumeExtractor::Result.new(
      text: 'fake resume text ' * 50,
      usable: usable,
      reason: reason
    )
    # Use Minitest::Mock to stub the class method
    ResumeExtractor.define_singleton_method(:extract) do |_cand|
      result
    end
  end
end
