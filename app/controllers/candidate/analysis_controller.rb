class Candidate::AnalysisController < Candidate::BaseController
  def index
    authorize @candidate, :show?
    @ai_scores = @candidate.ai_scores
                           .includes(:opening)
                           .order(processed_at: :desc)
  end
end
