class JdExtractionService
  def self.ensure_extracted(opening:, provider:)
    new(opening: opening, provider: provider).ensure_extracted
  end

  def initialize(opening:, provider:)
    @opening  = opening
    @provider = provider
  end

  # Extracts must_have/good_to_have from the JD and stores them on the opening.
  # Skips if the opening's jd_requirements_hash already matches the current JD —
  # meaning requirements are up to date and extraction has already been done.
  def ensure_extracted
    current_hash = PromptBuilder.jd_hash(@opening)
    return if @opening.jd_requirements_hash == current_hash

    prompt = PromptBuilder.build_extraction_prompt(@opening)
    result = @provider.extract_requirements(
      prompt:   prompt,
      metadata: { opening_id: @opening.id }
    )

    @opening.update!(
      must_have:            result[:must_have],
      good_to_have:         result[:good_to_have],
      jd_requirements_hash: current_hash
    )
  end
end
