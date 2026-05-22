require "test_helper"

class ChatgptProviderTest < ActiveSupport::TestCase
  def setup
    @provider = ChatgptProvider.new(api_key: 'test-key-12345')
  end

  test 'provider_key returns chatgpt' do
    assert_equal 'chatgpt', @provider.provider_key
  end

  test 'model returns gpt-4o-mini' do
    assert_equal 'gpt-4o-mini', @provider.model
  end

  test 'score parses valid response and returns correct hash' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => {
            score: 85,
            reasoning: 'Strong technical background with relevant experience.',
            matched_skills: { 'React' => 90, 'Node.js' => 85 },
            gaps: { 'Kubernetes' => 'Not mentioned' },
            strengths: ['Leadership', 'Technical depth'],
            concerns: ['Limited DevOps experience']
          }.to_json
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    result = @provider.score(prompt: 'test prompt')

    assert_equal 85, result[:score]
    assert_equal 'Strong technical background with relevant experience.', result[:reasoning]
    assert_equal({ 'React' => 90, 'Node.js' => 85 }, result[:matched_skills])
    assert_equal({ 'Kubernetes' => 'Not mentioned' }, result[:gaps])
    assert_equal ['Leadership', 'Technical depth'], result[:strengths]
    assert_equal ['Limited DevOps experience'], result[:concerns]
    assert_equal 100, result.dig(:tokens, :input)
    assert_equal 50, result.dig(:tokens, :output)
  end

  test 'score raises InvalidResponseError when score is out of range' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => {
            score: 150,
            reasoning: 'Out of range',
            matched_skills: {},
            gaps: {},
            strengths: [],
            concerns: []
          }.to_json
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    assert_raises(BaseAiProvider::InvalidResponseError) do
      @provider.score(prompt: 'test prompt')
    end
  end

  test 'score raises InvalidResponseError when JSON is malformed' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => 'not valid json'
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    assert_raises(BaseAiProvider::InvalidResponseError) do
      @provider.score(prompt: 'test prompt')
    end
  end

  test 'score raises InvalidResponseError when reasoning is blank' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => {
            score: 85,
            reasoning: '',
            matched_skills: {},
            gaps: {},
            strengths: [],
            concerns: []
          }.to_json
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    assert_raises(BaseAiProvider::InvalidResponseError) do
      @provider.score(prompt: 'test prompt')
    end
  end

  test 'estimate_cost calculates correctly' do
    cost = @provider.estimate_cost(input_tokens: 1_000_000, output_tokens: 500_000)
    expected = (1_000_000 * 0.15 / 1_000_000.0) + (500_000 * 0.60 / 1_000_000.0)
    assert_equal expected, cost
    assert_in_delta 0.45, cost, 0.0001
  end

  test 'api_key_from_env raises ScoringError when OPENAI_API_KEY not set' do
    ClimateControl.modify(OPENAI_API_KEY: nil) do
      assert_raises(BaseAiProvider::ScoringError) do
        ChatgptProvider.new(api_key: nil)
      end
    end
  end

  test 'score handles empty response content gracefully' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => nil
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    assert_raises(BaseAiProvider::InvalidResponseError) do
      @provider.score(prompt: 'test prompt')
    end
  end

  test 'score allows empty matched_skills and gaps when not present in response' do
    fake_response = {
      'choices' => [{
        'message' => {
          'content' => {
            score: 75,
            reasoning: 'Decent fit',
            matched_skills: nil,
            gaps: nil,
            strengths: [],
            concerns: []
          }.to_json
        }
      }],
      'usage' => { 'prompt_tokens' => 100, 'completion_tokens' => 50 }
    }

    mock_client = build_mock_client(fake_response)
    @provider.instance_variable_set(:@client, mock_client)

    result = @provider.score(prompt: 'test prompt')
    assert_equal({}, result[:matched_skills])
    assert_equal({}, result[:gaps])
  end

  # ---------------------------------------------------------------------------
  # Timeout tests
  # ---------------------------------------------------------------------------

  test 'READ_TIMEOUT constant is defined and is between 20 and 60 seconds' do
    assert defined?(ChatgptProvider::READ_TIMEOUT),
           'READ_TIMEOUT constant must be defined'
    assert_includes 20..60, ChatgptProvider::READ_TIMEOUT,
                    "READ_TIMEOUT should be 20–60 s, got #{ChatgptProvider::READ_TIMEOUT}"
  end

  test 'score wraps Net::ReadTimeout as ScoringError' do
    timeout_client = build_timeout_client
    @provider.instance_variable_set(:@client, timeout_client)

    err = assert_raises(BaseAiProvider::ScoringError) do
      @provider.score(prompt: 'test prompt')
    end
    assert_match(/timeout/i, err.message)
  end

  test 'extract_requirements wraps Net::ReadTimeout as ScoringError' do
    timeout_client = build_timeout_client
    @provider.instance_variable_set(:@client, timeout_client)

    err = assert_raises(BaseAiProvider::ScoringError) do
      @provider.extract_requirements(prompt: 'test prompt')
    end
    assert_match(/timeout/i, err.message)
  end

  private

  def build_timeout_client
    Class.new do
      def chat(parameters:)
        raise Net::ReadTimeout, 'execution expired'
      end
    end.new
  end

  def build_mock_client(response)
    Class.new do
      attr_reader :response

      def initialize(resp)
        @response = resp
      end

      def chat(parameters:)
        @response
      end
    end.new(response)
  end
end
