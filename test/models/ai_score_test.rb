require "test_helper"

class AiScoreTest < ActiveSupport::TestCase
  test "score must be present" do
    score = AiScore.new(reasoning: "Test", provider: "chatgpt", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:score], "can't be blank"
  end

  test "score must be in range 0..100" do
    score = AiScore.new(score: 101, reasoning: "Test", provider: "chatgpt", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:score], "must be in 0..100"

    score = AiScore.new(score: -1, reasoning: "Test", provider: "chatgpt", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:score], "must be in 0..100"
  end

  test "score must be an integer" do
    score = AiScore.new(score: 85.5, reasoning: "Test", provider: "chatgpt", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:score], "must be an integer"
  end

  test "reasoning must be present" do
    score = AiScore.new(score: 85, provider: "chatgpt", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:reasoning], "can't be blank"
  end

  test "provider must be present" do
    score = AiScore.new(score: 85, reasoning: "Test", model: "gpt-4o-mini")
    assert_not score.valid?
    assert_includes score.errors[:provider], "can't be blank"
  end

  test "model must be present" do
    score = AiScore.new(score: 85, reasoning: "Test", provider: "chatgpt")
    assert_not score.valid?
    assert_includes score.errors[:model], "can't be blank"
  end

  test "still_valid? returns true when is_valid is true and not expired" do
    score = ai_scores(:john_web_score)
    assert score.still_valid?
  end

  test "still_valid? returns false when is_valid is false" do
    score = ai_scores(:john_web_score)
    score.is_valid = false
    assert_not score.still_valid?
  end

  test "still_valid? returns false when expired" do
    score = ai_scores(:john_web_score)
    score.expires_at = 1.day.ago
    assert_not score.still_valid?
  end

  test "expired? returns false when expires_at is blank" do
    score = AiScore.new(expires_at: nil)
    assert_not score.expired?
  end

  test "expired? returns true when expires_at is in the past" do
    score = AiScore.new(expires_at: 1.day.ago)
    assert score.expired?
  end

  test "expired? returns false when expires_at is in the future" do
    score = AiScore.new(expires_at: 1.day.from_now)
    assert_not score.expired?
  end

  test "set_expiry sets default 90-day expiry on create" do
    score = AiScore.new(
      candidate: candidates(:john_doe),
      opening: openings(:web_opening),
      score: 85,
      reasoning: "Test",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      processed_at: Time.current
    )
    score.valid?
    assert_not_nil score.expires_at
    assert_in_delta score.expires_at, 90.days.from_now, 1.second
  end

  test "set_expiry respects existing expires_at" do
    custom_expiry = 60.days.from_now
    score = AiScore.new(
      candidate: candidates(:john_doe),
      opening: openings(:web_opening),
      score: 85,
      reasoning: "Test",
      provider: "chatgpt",
      model: "gpt-4o-mini",
      expires_at: custom_expiry
    )
    score.valid?
    assert_equal custom_expiry, score.expires_at
  end

  test "valid_scores scope returns only valid scores" do
    assert_includes AiScore.valid_scores, ai_scores(:john_web_score)
  end

  test "sorted_by_score scope orders by score descending" do
    scores = AiScore.sorted_by_score
    assert scores.first.score >= scores.second.score
  end
end
