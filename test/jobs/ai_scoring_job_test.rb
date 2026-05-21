require 'test_helper'

class AiScoringJobTest < ActiveJob::TestCase
  # Fake provider for testing
  class FakeProvider < BaseAiProvider
    PROVIDER_KEY = 'chatgpt'
    MODEL        = 'fake-1'

    attr_accessor :next_response, :calls, :should_raise_on_call

    def initialize
      super(api_key: 'fake')
      @calls = 0
      @should_raise_on_call = nil
    end

    def score(prompt:)
      @calls += 1
      if @should_raise_on_call && @calls == @should_raise_on_call
        raise BaseAiProvider::ScoringError.new('Mock API error')
      end
      @next_response
    end

    def extract_requirements(prompt:)
      { must_have: [], good_to_have: [], tokens: { input: 0, output: 0 } }
    end

    def estimate_cost(input_tokens:, output_tokens:)
      (input_tokens + output_tokens) * 0.000001
    end

    private

    def api_key_from_env
      'fake'
    end
  end

  setup do
    @opening   = openings(:mobile_opening)
    @user      = users(:recruiter)
    @batch_id  = SecureRandom.uuid

    # Create a fake provider for injection
    @fake_provider = FakeProvider.new

    # Default response
    @fake_provider.next_response = {
      score: 80, reasoning: 'good', matched_skills: {}, gaps: {},
      strengths: [], concerns: [],
      tokens: { input: 100, output: 50 }
    }

    # Store the original extract method so we can restore it
    @original_extract_method = ResumeExtractor.method(:extract)

    # Mock ResumeExtractor to always return usable text
    mock_extraction_default

    # Store the original jd_hash method so we can restore it
    @original_jd_hash_method = PromptBuilder.method(:jd_hash)

    # Make PromptBuilder.jd_hash return a consistent hash
    PromptBuilder.define_singleton_method(:jd_hash) do |_opening|
      'a' * 64  # Return a valid 64-char hash
    end
  end

  teardown do
    # Restore the original extract method
    if @original_extract_method.is_a?(Method)
      ResumeExtractor.define_singleton_method(:extract, @original_extract_method)
    end
    # Restore the original jd_hash method
    if @original_jd_hash_method.is_a?(Method)
      PromptBuilder.define_singleton_method(:jd_hash, @original_jd_hash_method)
    end
    @fake_provider = nil
  end

  # Test 1: Happy path — 3 candidates with resumes → 3 AiScores created
  def test_happy_path_scores_all_candidates
    # Create 3 candidates for the opening
    candidates = create_candidates_with_resumes(3)

    # Perform the job
    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    # Verify log was created and marked completed
    log = AiScoringLog.find_by(batch_id: @batch_id)
    assert_not_nil log
    assert_equal @opening.id, log.opening_id
    assert_equal 'completed', log.status
    assert_equal 3, log.total_candidates
    assert_equal 3, log.successfully_scored
    assert_equal 0, log.failed_count
    assert_not_nil log.started_at
    assert_not_nil log.completed_at
    assert log.total_cost > 0

    # Verify 3 AiScores were created for this opening
    opening_scores = AiScore.where(opening_id: @opening.id)
    assert_equal 3, opening_scores.count
    opening_scores.each do |score|
      assert_equal 80, score.score
      assert_equal 'good', score.reasoning
      assert_equal 'chatgpt', score.provider
      assert_equal 'fake-1', score.model
      assert score.is_valid
      assert_nil score.invalidation_reason
    end

    # Verify provider was called 3 times
    assert_equal 3, @fake_provider.calls
  end

  # Test 2: Idempotency — enqueueing twice with same batch_id doesn't double-score
  def test_idempotency_same_batch_id_no_double_processing
    candidates = create_candidates_with_resumes(2)

    # First run
    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    first_call_count = @fake_provider.calls
    assert_equal 2, first_call_count

    # Second run with same batch_id — should return early
    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    # Provider should NOT have been called again
    assert_equal first_call_count, @fake_provider.calls
    # Only 2 scores for this opening, not 4
    assert_equal 2, AiScore.where(opening_id: @opening.id).count
  end

  # Test 4: No candidates — opening with zero candidates
  def test_no_candidates_logs_completed
    # Don't create any candidates for this opening

    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    log = AiScoringLog.find_by(batch_id: @batch_id)
    assert_equal 'completed', log.status
    assert_equal 0, log.total_candidates
    assert_equal 0, log.successfully_scored
    assert_equal 0, log.failed_count
    assert_equal 0, @fake_provider.calls
  end

  # Test 5: Provider error mid-batch — one candidate fails, others succeed
  def test_provider_error_mid_batch_records_failure
    candidates = create_candidates_with_resumes(3)

    # Make provider raise error on second call
    @fake_provider.should_raise_on_call = 2

    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    log = AiScoringLog.find_by(batch_id: @batch_id)
    assert_equal 'completed', log.status
    assert_equal 3, log.total_candidates
    assert_equal 2, log.successfully_scored
    assert_equal 1, log.failed_count
  end

  # Test 6: Unknown provider raises ArgumentError
  def test_unknown_provider_raises_error
    create_candidates_with_resumes(1)

    assert_raises ArgumentError do
      AiScoringJob.perform_now(
        opening_id: @opening.id,
        batch_id: @batch_id,
        requested_by_id: @user.id,
        provider_key: 'unknown_provider'
      )
    end
  end

  # Test 7: Job can be enqueued without performing
  def test_job_can_be_enqueued
    assert_enqueued_with(job: AiScoringJob) do
      AiScoringJob.perform_later(
        opening_id: @opening.id,
        batch_id: @batch_id,
        requested_by_id: @user.id
      )
    end
  end

  # Test 8: Log status transitions correctly
  def test_log_status_transitions
    candidates = create_candidates_with_resumes(1)

    # Before job runs, log should not exist
    assert_nil AiScoringLog.find_by(batch_id: @batch_id)

    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    log = AiScoringLog.find_by(batch_id: @batch_id)
    assert_equal 'completed', log.status
    assert log.started_at.present?
    assert log.completed_at.present?
    assert log.started_at <= log.completed_at
  end

  # Test 9: Resume hash and JD hash are stored correctly
  def test_ai_scores_store_version_hashes
    candidates = create_candidates_with_resumes(1)

    AiScoringJob.perform_now(
      opening_id: @opening.id,
      batch_id: @batch_id,
      requested_by_id: @user.id,
      provider_key: 'chatgpt',
      provider: @fake_provider
    )

    ai_score = AiScore.where(opening_id: @opening.id).first
    assert_not_nil ai_score
    assert ai_score.resume_version_hash.present?
    assert_equal 'a' * 64, ai_score.jd_version_hash
  end

  # Test 10: Error during processing marks log as failed and re-raises
  def test_error_during_processing_marks_failed_and_re_raises
    candidates = create_candidates_with_resumes(1)

    # Override provider to raise a non-ScoringError
    @fake_provider.define_singleton_method(:score) do |prompt:|
      raise StandardError.new('Database connection lost')
    end

    assert_raises StandardError do
      AiScoringJob.perform_now(
        opening_id: @opening.id,
        batch_id: @batch_id,
        requested_by_id: @user.id,
        provider_key: 'chatgpt',
        provider: @fake_provider
      )
    end

    log = AiScoringLog.find_by(batch_id: @batch_id)
    assert_equal 'failed', log.status
    assert_includes log.error_details, 'Database connection lost'
    assert log.completed_at.present?
  end

  # Helper methods
  private

  def mock_extraction_default
    result = ResumeExtractor::Result.new(
      text: 'fake resume text ' * 50,
      usable: true,
      reason: nil
    )
    ResumeExtractor.define_singleton_method(:extract) do |_cand|
      result
    end
  end

  def create_candidates_with_resumes(count)
    count.times do |i|
      candidate = Candidate.create!(
        first_name: "Candidate#{i}",
        last_name: "Test#{i}",
        email: "candidate#{i}@example.com",
        phone: "555000#{i}",
        location: "City#{i}",
        experience: 3 + i,
        bucket: :recent,
        role: roles(:software_engineer),
        source: sources(:linkedin),
        opening: @opening,
        user: @user,
        owner: @user,
        next_recycle_on: 30.days.from_now
      )
      candidate.resume.attach(
        io: StringIO.new('%PDF-1.4 fake'),
        filename: "resume_#{i}.pdf",
        content_type: 'application/pdf'
      )
      candidate
    end
  end
end
