require "test_helper"

class Candidate::AnalysisControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :openings, :candidates, :ai_scores, :roles

  setup do
    @user      = users(:recruiter)
    @candidate = candidates(:john_doe)
  end

  test "index redirects to login if not signed in" do
    get candidate_analysis_path(@candidate)
    assert_redirected_to new_session_path
  end

  test "index returns 200 when signed in" do
    login_user(@user)
    get candidate_analysis_path(@candidate)
    assert_response :success
  end

  test "index returns 200 for a candidate with no ai scores" do
    login_user(@user)
    @candidate.ai_scores.destroy_all
    get candidate_analysis_path(@candidate)
    assert_response :success
  end

  test "index returns 200 for an interviewer" do
    login_user(users(:interviewer))
    get candidate_analysis_path(@candidate)
    # All authenticated roles can view candidate read pages (matches CandidatesController#show)
    assert_response :success
  end

  private

  def login_user(user)
    post session_url, params: { email: user.email, password: "password" }
  end
end
