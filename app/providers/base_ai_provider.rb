class BaseAiProvider
  PROVIDER_KEY = nil  # Subclasses override
  MODEL        = nil  # Subclasses override

  class ScoringError < StandardError; end
  class InvalidResponseError < ScoringError; end

  def initialize(api_key: nil)
    @api_key = api_key || api_key_from_env
  end

  def provider_key
    self.class::PROVIDER_KEY or raise NotImplementedError, "#{self.class} must set PROVIDER_KEY"
  end

  def model
    self.class::MODEL or raise NotImplementedError, "#{self.class} must set MODEL"
  end

  # Returns: { score: Integer, reasoning: String, matched_skills: Hash,
  #            gaps: Hash, strengths: Array, concerns: Array,
  #            tokens: { input: Integer, output: Integer } }
  # metadata: optional hash passed through to LangSmith traces (e.g. opening_id, candidate_id)
  def score(prompt:, metadata: {})
    raise NotImplementedError
  end

  # Returns: { must_have: Array<String>, good_to_have: Array<String>,
  #            tokens: { input: Integer, output: Integer } }
  # metadata: optional hash passed through to LangSmith traces (e.g. opening_id)
  def extract_requirements(prompt:, metadata: {})
    raise NotImplementedError
  end

  def estimate_cost(input_tokens:, output_tokens:)
    raise NotImplementedError
  end

  private

  def api_key_from_env
    raise NotImplementedError
  end
end
