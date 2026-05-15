require "test_helper"

class AiScoringLogTest < ActiveSupport::TestCase
  test "batch_id must be present" do
    log = AiScoringLog.new(
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      status: "pending",
      provider: "chatgpt",
      model: "gpt-4o-mini"
    )
    assert_not log.valid?
    assert_includes log.errors[:batch_id], "can't be blank"
  end

  test "batch_id must be unique" do
    existing_log = ai_scoring_logs(:web_opening_log)
    new_log = AiScoringLog.new(
      batch_id: existing_log.batch_id,
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      status: "pending",
      provider: "chatgpt",
      model: "gpt-4o-mini"
    )
    assert_not new_log.valid?
    assert_includes new_log.errors[:batch_id], "has already been taken"
  end

  test "status defaults to pending" do
    log = AiScoringLog.new(
      batch_id: SecureRandom.uuid,
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      provider: "chatgpt",
      model: "gpt-4o-mini"
    )
    assert log.valid?
    assert_equal "pending", log.status
  end

  test "status must be in allowed list" do
    log = AiScoringLog.new(
      batch_id: SecureRandom.uuid,
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      status: "invalid_status",
      provider: "chatgpt",
      model: "gpt-4o-mini"
    )
    assert_not log.valid?
    assert_includes log.errors[:status], "is not included in the list"
  end

  test "valid statuses are accepted" do
    AiScoringLog::STATUSES.each do |status|
      log = AiScoringLog.new(
        batch_id: SecureRandom.uuid,
        opening: openings(:web_opening),
        requested_by: users(:recruiter),
        status: status,
        provider: "chatgpt",
        model: "gpt-4o-mini"
      )
      assert log.valid?, "Status '#{status}' should be valid"
    end
  end

  test "provider must be present" do
    log = AiScoringLog.new(
      batch_id: SecureRandom.uuid,
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      status: "pending",
      model: "gpt-4o-mini"
    )
    assert_not log.valid?
    assert_includes log.errors[:provider], "can't be blank"
  end

  test "model must be present" do
    log = AiScoringLog.new(
      batch_id: SecureRandom.uuid,
      opening: openings(:web_opening),
      requested_by: users(:recruiter),
      status: "pending",
      provider: "chatgpt"
    )
    assert_not log.valid?
    assert_includes log.errors[:model], "can't be blank"
  end

  test "recent scope orders by created_at descending" do
    logs = AiScoringLog.recent
    assert logs.first.created_at >= logs.second.created_at
  end
end
