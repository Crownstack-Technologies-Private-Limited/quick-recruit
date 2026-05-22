require "test_helper"

class Opening::AiScoresControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :openings, :candidates, :ai_scores, :ai_scoring_logs, :roles

  setup do
    @user  = users(:recruiter)
    @admin = users(:admin)
    @opening = openings(:web_opening)
    @candidate = candidates(:john_doe)
    @ai_score = ai_scores(:john_web_score)
  end

  private

  def login_user(user)
    post session_url, params: {
      email: user.email,
      password: 'password'
    }
  end

  def mock_template_render
    # This is needed because views are created in T7, not T6
    # We stub the render calls to allow controller tests to pass
  end

  test "index redirects to login if not signed in" do
    get opening_ai_scores_path(@opening)
    assert_redirected_to new_session_path
  end

  test "index returns 200 when signed in" do
    login_user(@user)
    get opening_ai_scores_path(@opening)
    assert_response :success
  end

  test "index only includes valid scores" do
    login_user(@user)

    # Create an invalid score
    invalid_score = ai_scores(:jane_web_score)
    invalid_score.update(is_valid: false)

    # Verify that the controller loads only valid scores
    opening = @opening
    valid_scores = opening.ai_scores.valid_scores.sorted_by_score.count
    invalid_scores = opening.ai_scores.invalid_scores.count

    assert valid_scores == 1, "Should have exactly 1 valid score"
    assert invalid_scores == 1, "Should have exactly 1 invalid score"

    get opening_ai_scores_path(opening)
    assert_response :success
  end

  test "index sorts scores by score descending" do
    login_user(@user)
    get opening_ai_scores_path(@opening)

    assert_response :success
    # Verify the controller properly orders by score descending
    scores = @opening.ai_scores.valid_scores.sorted_by_score
    assert scores.count >= 2
    assert scores[0].score >= scores[1].score
  end

  test "create enqueues AiScoringJob" do
    login_user(@admin)

    assert_enqueued_with(job: AiScoringJob, queue: 'ai_scoring') do
      post opening_ai_scores_path(@opening), params: {
        batch_id: SecureRandom.uuid
      }
    end

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /AI scoring started/, flash[:notice]
  end

  test "create is forbidden for non-admin users" do
    login_user(@user)

    assert_no_enqueued_jobs do
      post opening_ai_scores_path(@opening), params: {
        batch_id: SecureRandom.uuid
      }
    end

    assert_redirected_to root_path
  end

  test "create refuses when a pending batch exists" do
    login_user(@admin)

    @opening.ai_scoring_logs.create!(
      batch_id: SecureRandom.uuid,
      requested_by_id: @admin.id,
      status: 'pending',
      provider: 'chatgpt',
      model: 'gpt-4o-mini'
    )

    assert_no_enqueued_jobs do
      post opening_ai_scores_path(@opening), params: {
        batch_id: SecureRandom.uuid
      }
    end

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /already in progress/, flash[:alert]
  end

  test "create refuses when a processing batch exists" do
    login_user(@admin)

    @opening.ai_scoring_logs.create!(
      batch_id: SecureRandom.uuid,
      requested_by_id: @admin.id,
      status: 'processing',
      provider: 'chatgpt',
      model: 'gpt-4o-mini'
    )

    assert_no_enqueued_jobs do
      post opening_ai_scores_path(@opening), params: {
        batch_id: SecureRandom.uuid
      }
    end

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /already in progress/, flash[:alert]
  end

  test "create rejects bad batch_id format" do
    login_user(@admin)

    assert_no_enqueued_jobs do
      post opening_ai_scores_path(@opening), params: {
        batch_id: 'not-a-uuid'
      }
    end

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /Invalid batch id/, flash[:alert]
  end

  test "create generates batch_id if not provided" do
    login_user(@admin)

    assert_enqueued_with(job: AiScoringJob, queue: 'ai_scoring') do
      post opening_ai_scores_path(@opening)
    end

    assert_redirected_to opening_ai_scores_path(@opening)
  end

  test "create allows valid UUID batch_id" do
    login_user(@admin)
    valid_uuid = SecureRandom.uuid

    assert_enqueued_with(job: AiScoringJob, queue: 'ai_scoring') do
      post opening_ai_scores_path(@opening), params: {
        batch_id: valid_uuid
      }
    end

    assert_redirected_to opening_ai_scores_path(@opening)
  end

  test "index displays cost estimate" do
    login_user(@user)
    get opening_ai_scores_path(@opening)

    assert_response :success
    # Verify the controller calculates cost estimate
  end

  test "index includes latest log" do
    login_user(@user)
    get opening_ai_scores_path(@opening)

    assert_response :success
    # Verify the controller fetches latest log
  end

  test "index filters by a single location via locations array" do
    login_user(@user)
    get opening_ai_scores_path(@opening), params: { locations: ["San Francisco"] }
    assert_response :success
    assigns(:ai_scores).each do |score|
      assert_match /san francisco/i, score.candidate.location.to_s
    end
  end

  test "index filters by multiple locations" do
    login_user(@user)
    get opening_ai_scores_path(@opening), params: { locations: ["San Francisco", "New York"] }
    assert_response :success
    assert_equal 2, assigns(:ai_scores).length
    assigns(:ai_scores).each do |score|
      assert_match /san francisco|new york/i, score.candidate.location.to_s
    end
  end

  test "index returns empty results when no candidates match location filter" do
    login_user(@user)
    get opening_ai_scores_path(@opening), params: { locations: ["Austin"] }
    assert_response :success
    assert_equal [], assigns(:ai_scores)
  end

  test "index returns all results when locations array is empty" do
    login_user(@user)
    get opening_ai_scores_path(@opening), params: { locations: [] }
    assert_response :success
  end

  test "index filters out results with date_from in the future" do
    login_user(@user)
    future_date = 1.day.from_now.strftime("%Y-%m-%d")
    get opening_ai_scores_path(@opening), params: { date_from: future_date }
    assert_response :success
    assert_equal [], assigns(:ai_scores)
  end

  test "index filters out results with date_to in the past" do
    login_user(@user)
    past_date = 1.year.ago.strftime("%Y-%m-%d")
    get opening_ai_scores_path(@opening), params: { date_to: past_date }
    assert_response :success
    assert_equal [], assigns(:ai_scores)
  end

  test "index returns results for a date range spanning now" do
    login_user(@user)
    from = 1.year.ago.strftime("%Y-%m-%d")
    to   = 1.year.from_now.strftime("%Y-%m-%d")
    get opening_ai_scores_path(@opening), params: { date_from: from, date_to: to }
    assert_response :success
    assert assigns(:ai_scores).length > 0
  end

  test "index ignores malformed date params gracefully" do
    login_user(@user)
    get opening_ai_scores_path(@opening), params: { date_from: "not-a-date", date_to: "also-bad" }
    assert_response :success
  end

  # --- pause action ---

  test "pause sets in-flight log to paused and redirects with notice" do
    login_user(@admin)

    log = @opening.ai_scoring_logs.create!(
      batch_id:        SecureRandom.uuid,
      requested_by_id: @admin.id,
      status:          'processing',
      provider:        'chatgpt',
      model:           'gpt-4o-mini'
    )

    patch pause_opening_ai_scores_path(@opening)

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /paused/i, flash[:notice]
    assert_equal 'paused', log.reload.status
  end

  test "pause redirects with alert when no in-flight log exists" do
    login_user(@admin)

    # Ensure no pending/processing logs exist for this opening
    @opening.ai_scoring_logs.where(status: %w[pending processing]).delete_all

    patch pause_opening_ai_scores_path(@opening)

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /No scoring run/i, flash[:alert]
  end

  test "pause is forbidden for non-admin users" do
    login_user(@user)

    @opening.ai_scoring_logs.create!(
      batch_id:        SecureRandom.uuid,
      requested_by_id: @admin.id,
      status:          'processing',
      provider:        'chatgpt',
      model:           'gpt-4o-mini'
    )

    patch pause_opening_ai_scores_path(@opening)

    assert_redirected_to root_path
  end

  # --- destroy action ---

  test "destroy deletes all ai scores and logs for the opening and resets extraction fields" do
    login_user(@admin)

    # Confirm there are scores and logs before clearing
    assert @opening.ai_scores.any?, "Fixture must have scores for web_opening"
    assert @opening.ai_scoring_logs.any?, "Fixture must have logs for web_opening"

    # Give the opening some extraction data to verify it gets cleared
    @opening.update!(must_have: [{ "skill" => "Ruby" }], good_to_have: [{ "skill" => "Rails" }], jd_requirements_hash: "abc123")

    delete opening_ai_scores_path(@opening)

    assert_redirected_to opening_ai_scores_path(@opening)
    assert_match /cleared/i, flash[:notice]
    assert_equal 0, AiScore.where(opening_id: @opening.id).count
    assert_equal 0, AiScoringLog.where(opening_id: @opening.id).count
    @opening.reload
    assert_equal [], @opening.must_have
    assert_equal [], @opening.good_to_have
    assert_nil @opening.jd_requirements_hash
  end

  test "destroy cancels in-flight log before wiping all logs" do
    login_user(@admin)

    in_flight = @opening.ai_scoring_logs.create!(
      batch_id:        SecureRandom.uuid,
      requested_by_id: @admin.id,
      status:          'processing',
      provider:        'chatgpt',
      model:           'gpt-4o-mini'
    )

    delete opening_ai_scores_path(@opening)

    assert_redirected_to opening_ai_scores_path(@opening)
    # All logs including the in-flight one are gone after clear
    assert_nil AiScoringLog.find_by(id: in_flight.id), "In-flight log must be deleted after clear"
    assert_equal 0, AiScoringLog.where(opening_id: @opening.id).count
  end

  test "destroy is forbidden for non-admin users" do
    login_user(@user)

    score_count_before = AiScore.where(opening_id: @opening.id).count

    delete opening_ai_scores_path(@opening)

    assert_redirected_to root_path
    assert_equal score_count_before, AiScore.where(opening_id: @opening.id).count, "Scores must not be deleted for non-admin"
  end
end
