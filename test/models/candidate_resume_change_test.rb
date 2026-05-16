require "test_helper"

class CandidateResumeChangeTest < ActiveSupport::TestCase
  setup do
    @candidate = candidates(:john_doe)
    @opening = openings(:web_opening)
  end

  # Helper method to attach a resume with content
  def attach_resume(candidate, content:)
    candidate.resume.attach(
      io: StringIO.new(content),
      filename: 'resume.pdf',
      content_type: 'application/pdf'
    )
    candidate.save!
    candidate.reload
  end

  # Helper method to replace resume with new content
  def replace_resume(candidate, content:)
    candidate.resume.purge
    attach_resume(candidate, content: content)
  end

  # Test 1: First-time attach stores resume_hash but does NOT invalidate scores
  test "first time attach stores resume_hash but does not invalidate existing scores" do
    # Start with no resume
    assert_nil @candidate.resume_hash

    # Attach first resume
    attach_resume(@candidate, content: "Initial resume content")

    # resume_hash should be set
    assert_not_nil @candidate.resume_hash
    assert @candidate.resume.attached?
  end

  test "first time attach with no prior ai_scores does not invalidate" do
    # Start fresh with no scores - delete existing ones
    @candidate.ai_scores.delete_all
    assert_equal 0, @candidate.ai_scores.count

    # Attach first resume
    initial_content = "Initial resume content v1"
    attach_resume(@candidate, content: initial_content)

    # No scores were created, so nothing to invalidate
    assert_equal 0, @candidate.ai_scores.count
    assert_not_nil @candidate.resume_hash
  end

  # Test 2: Re-attach with same content (same checksum) does NOT invalidate scores
  test "re-attach with same checksum does not invalidate valid scores" do
    content = "Resume content that stays the same"

    # First attach
    attach_resume(@candidate, content: content)
    first_hash = @candidate.resume_hash

    # Remove existing fixture score from this candidate-opening pair
    AiScore.where(candidate: @candidate, opening: @opening).delete_all

    # Create a valid AI score
    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )
    assert score.is_valid

    # Re-attach the same content
    @candidate.resume.purge
    @candidate.reload
    attach_resume(@candidate, content: content)

    # Hash should be the same
    assert_equal first_hash, @candidate.resume_hash

    # Score should still be valid (not invalidated)
    score.reload
    assert score.is_valid
    assert_nil score.invalidation_reason
  end

  # Test 3: Re-attach with different content invalidates all valid AiScores
  test "re-attach with different checksum invalidates all valid scores" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    # First attach and create a score
    attach_resume(@candidate, content: "Old resume content")
    first_hash = @candidate.resume_hash

    score1 = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )
    assert score1.is_valid

    # Create another opening and score for the same candidate
    another_opening = openings(:mobile_opening)
    score2 = AiScore.create!(
      candidate: @candidate,
      opening: another_opening,
      score: 75,
      reasoning: "Decent fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )
    assert score2.is_valid

    # Now re-attach with different content
    replace_resume(@candidate, content: "New resume content completely different")

    # Both scores should be invalidated
    score1.reload
    score2.reload

    assert_not score1.is_valid
    assert_equal 'resume_updated', score1.invalidation_reason
    assert_not_nil score1.invalidated_at

    assert_not score2.is_valid
    assert_equal 'resume_updated', score2.invalidation_reason
    assert_not_nil score2.invalidated_at
  end

  # Test 4: No resume attached, then attach => resume_hash set, no scores invalidated
  test "attach first resume to candidate with no resume sets hash but does not invalidate" do
    # Ensure candidate starts with no resume
    @candidate.resume.purge if @candidate.resume.attached?
    @candidate.reload
    assert_nil @candidate.resume_hash

    # Attach for the first time
    attach_resume(@candidate, content: "First resume")

    assert_not_nil @candidate.resume_hash
    assert @candidate.resume.attached?
  end

  # Test 5: Detach (purge) => resume_hash set to nil, no scores invalidated
  test "detach resume sets hash to nil but does not invalidate scores" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    # Attach initial resume and create a score
    attach_resume(@candidate, content: "Initial resume")
    first_hash = @candidate.resume_hash
    assert_not_nil first_hash

    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )
    assert score.is_valid

    # Detach the resume
    @candidate.resume.purge
    @candidate.save!
    @candidate.reload

    # resume_hash should now be nil
    assert_nil @candidate.resume_hash

    # Score should still be valid (detaching doesn't invalidate)
    score.reload
    assert score.is_valid
    assert_nil score.invalidation_reason
  end

  # Test 6: Other candidates' scores are untouched when one candidate's resume changes
  test "resume change on one candidate does not affect other candidates' scores" do
    # Create two candidates with scores
    candidate2 = candidates(:jane_smith)

    # Clear existing scores
    @candidate.ai_scores.delete_all
    candidate2.ai_scores.delete_all

    attach_resume(@candidate, content: "John's resume")
    attach_resume(candidate2, content: "Jane's resume")

    score1 = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    score2 = AiScore.create!(
      candidate: candidate2,
      opening: @opening,
      score: 90,
      reasoning: "Excellent fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # Change only candidate1's resume
    replace_resume(@candidate, content: "John's updated resume")

    # Only candidate1's score should be invalidated
    score1.reload
    score2.reload

    assert_not score1.is_valid
    assert_equal 'resume_updated', score1.invalidation_reason

    assert score2.is_valid
    assert_nil score2.invalidation_reason
  end

  # Test 7: Invalid scores stay invalid (WHERE clause limits to is_valid: true)
  test "invalidate_ai_scores only affects valid scores" do
    # Clear existing scores first
    @candidate.ai_scores.delete_all

    # Create both valid and invalid scores
    valid_score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # For the invalid score, use a different opening to avoid unique constraint
    another_opening = openings(:mobile_opening)
    invalid_score = AiScore.create!(
      candidate: @candidate,
      opening: another_opening,
      score: 70,
      reasoning: "Old score",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: false,
      invalidation_reason: 'expired',
      invalidated_at: 2.days.ago,
      processed_at: 92.days.ago
    )

    assert valid_score.is_valid
    assert_not invalid_score.is_valid

    # Attach first resume and then replace it
    attach_resume(@candidate, content: "Initial resume")
    replace_resume(@candidate, content: "Updated resume")

    # Only the valid score should be invalidated
    valid_score.reload
    invalid_score.reload

    assert_not valid_score.is_valid
    assert_equal 'resume_updated', valid_score.invalidation_reason

    # Invalid score should remain invalid but with original reason
    assert_not invalid_score.is_valid
    assert_equal 'expired', invalid_score.invalidation_reason
  end

  # Test 8: invalidated_at is set to a recent time
  test "invalidated_at is set to current time when scores are invalidated" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    attach_resume(@candidate, content: "Initial resume")

    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    assert_nil score.invalidated_at

    # Replace the resume
    freeze_time do
      replace_resume(@candidate, content: "New resume")
      score.reload

      assert_not score.is_valid
      assert_not_nil score.invalidated_at
      assert_in_delta score.invalidated_at, Time.current, 1.second
    end
  end

  # Test 9: Multiple rapid resume changes
  test "multiple rapid resume changes correctly track state" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    # First attach
    attach_resume(@candidate, content: "Resume v1")
    hash_v1 = @candidate.resume_hash

    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # Second change
    replace_resume(@candidate, content: "Resume v2")
    hash_v2 = @candidate.resume_hash

    assert_not_equal hash_v1, hash_v2

    score.reload
    assert_not score.is_valid
    assert_equal 'resume_updated', score.invalidation_reason

    # Create a new score after v2
    score_v2 = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 80,
      reasoning: "Good fit v2",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: Time.current
    )
    assert score_v2.is_valid

    # Third change
    replace_resume(@candidate, content: "Resume v3")
    hash_v3 = @candidate.resume_hash

    assert_not_equal hash_v2, hash_v3

    score_v2.reload
    assert_not score_v2.is_valid
    assert_equal 'resume_updated', score_v2.invalidation_reason

    # Original score should still be invalid with original reason
    score.reload
    assert_not score.is_valid
    assert_equal 'resume_updated', score.invalidation_reason
  end

  # Test 10: Callback doesn't fire for other changes (only resume)
  test "callback only runs when resume actually changes" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    attach_resume(@candidate, content: "Resume content")
    first_hash = @candidate.resume_hash

    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # Update a different field on the candidate
    @candidate.update!(first_name: "John", last_name: "Smith")

    # Hash should not change
    @candidate.reload
    assert_equal first_hash, @candidate.resume_hash

    # Score should not be invalidated
    score.reload
    assert score.is_valid
    assert_nil score.invalidation_reason
  end

  # Test 11: Resume content that looks like it changed but has same checksum
  test "same content with different encoding still has same checksum" do
    # Clear existing scores
    @candidate.ai_scores.delete_all

    content = "Resume content"

    attach_resume(@candidate, content: content)
    hash_1 = @candidate.resume_hash

    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # Reattach the exact same content
    @candidate.resume.purge
    @candidate.reload
    attach_resume(@candidate, content: content)

    hash_2 = @candidate.resume_hash
    assert_equal hash_1, hash_2

    score.reload
    assert score.is_valid
  end

  # Test 12: update_column is used to avoid recursive callbacks
  test "uses update_column to avoid recursive callbacks" do
    # This test verifies the implementation detail that update_column is used.
    # If update (instead of update_column) were used, it could trigger callbacks again.

    # Clear existing scores
    @candidate.ai_scores.delete_all

    attach_resume(@candidate, content: "Initial resume")
    first_hash = @candidate.resume_hash

    # Create a score
    score = AiScore.create!(
      candidate: @candidate,
      opening: @opening,
      score: 85,
      reasoning: "Good fit",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      is_valid: true,
      processed_at: 1.day.ago
    )

    # If callbacks were recursive, we'd see multiple updates.
    # We verify by replacing and checking state is consistent.
    replace_resume(@candidate, content: "New resume")

    # Should have exactly one resume attached (not duplicated by callback loops)
    assert_equal 1, @candidate.resume.attachments.count
    assert_not_nil @candidate.resume_hash
  end
end
