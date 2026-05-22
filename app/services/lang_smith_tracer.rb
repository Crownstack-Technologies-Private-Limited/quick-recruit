# Sends LLM run traces to LangSmith for cost + latency observability.
#
# Usage:
#   LangSmithTracer.trace(
#     name:       'candidate_scoring',
#     inputs:     { prompt: '...' },
#     outputs:    { score: 82 },
#     tokens:     { input: 950, output: 210 },
#     cost:       0.000267,
#     metadata:   { opening_id: 1, candidate_id: 5 },
#     tags:       ['scoring'],
#     start_time: start,
#     end_time:   Time.current
#   )
#
# Configuration (environment variables):
#   LANGSMITH_API_KEY  — required to enable tracing
#   LANGSMITH_PROJECT  — optional, defaults to "quick-recruit-#{Rails.env}"
#
# Fire-and-forget: failures are logged as warnings and never propagate.
class LangSmithTracer
  ENDPOINT = 'https://api.smith.langchain.com/runs'.freeze
  # Truncate prompt text stored in LangSmith to avoid huge payloads.
  # Set to nil to store full prompts (higher LangSmith storage cost).
  PROMPT_TRUNCATE_AT = 2_000

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  def self.trace(**kwargs)
    return unless enabled?

    new.trace(**kwargs)
  end

  def self.enabled?
    ENV['LANGSMITH_API_KEY'].present?
  end

  def self.project
    ENV.fetch('LANGSMITH_PROJECT', "quick-recruit-#{Rails.env}")
  end

  # --------------------------------------------------------------------------
  # Instance
  # --------------------------------------------------------------------------

  def trace(
    name:,
    run_type:   'llm',
    inputs:     {},
    outputs:    {},
    tokens:     { input: 0, output: 0 },
    cost:       0,
    metadata:   {},
    tags:       [],
    start_time:,
    end_time:,
    error:      nil
  )
    payload = build_payload(
      name:       name,
      run_type:   run_type,
      inputs:     truncate_inputs(inputs),
      outputs:    outputs,
      tokens:     tokens,
      cost:       cost,
      metadata:   metadata,
      tags:       Array(tags),
      start_time: start_time,
      end_time:   end_time,
      error:      error
    )

    send_async(payload)
  end

  private

  def build_payload(name:, run_type:, inputs:, outputs:, tokens:, cost:, metadata:, tags:, start_time:, end_time:, error:)
    {
      id:           SecureRandom.uuid,
      name:         name,
      run_type:     run_type,
      session_name: self.class.project,
      inputs:       inputs,
      outputs:      outputs,
      start_time:   start_time.utc.iso8601(3),
      end_time:     end_time.utc.iso8601(3),
      extra: {
        metadata: metadata.merge(
          input_tokens:  tokens[:input],
          output_tokens: tokens[:output],
          total_tokens:  tokens[:input].to_i + tokens[:output].to_i,
          cost_usd:      cost.to_f.round(6)
        )
      },
      tags:  tags,
      error: error
    }.compact
  end

  def truncate_inputs(inputs)
    return inputs unless PROMPT_TRUNCATE_AT

    inputs.transform_values do |v|
      v.is_a?(String) && v.length > PROMPT_TRUNCATE_AT ? "#{v.first(PROMPT_TRUNCATE_AT)}…[truncated]" : v
    end
  end

  def send_async(payload)
    Thread.new do
      send_sync(payload)
    rescue => e
      Rails.logger.warn("[LangSmith] Failed to send trace: #{e.class} #{e.message}")
    end
  end

  def send_sync(payload)
    uri  = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = 5
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json',
                                        'x-api-key'    => ENV['LANGSMITH_API_KEY'])
    req.body = payload.to_json

    resp = http.request(req)
    unless resp.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[LangSmith] #{resp.code}: #{resp.body&.first(300)}")
    end
  rescue => e
    Rails.logger.warn("[LangSmith] HTTP error: #{e.class} #{e.message}")
  end
end
