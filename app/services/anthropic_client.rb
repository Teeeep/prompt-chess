require 'faraday'

class AnthropicClient
  BASE_URL = 'https://api.anthropic.com/v1/'
  API_VERSION = '2023-06-01'

  # Initialize Anthropic API client
  #
  # @param api_key [String] Anthropic API key (starts with 'sk-ant-')
  # @param model [String] Claude model identifier
  def initialize(api_key:, model:)
    @api_key = api_key
    @model = model
  end

  # Test API connection by making minimal API call
  #
  # @return [Hash] Result with :success (Boolean) and :message (String)
  def test_connection
    response = connection.post('messages') do |req|
      req.body = {
        model: @model,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'Hi' }]
      }
    end

    if response.success?
      { success: true, message: 'Connected successfully to Anthropic API' }
    else
      parse_error(response)
    end
  rescue Faraday::ConnectionFailed => e
    { success: false, message: "Network error: #{e.message}" }
  rescue Faraday::Error => e
    { success: false, message: "Network error: #{e.message}" }
  end

  # Make completion request to Anthropic API
  # (To be implemented in Phase 4 - Agent Move Generation)
  #
  # @param prompt [String] User prompt
  # @param max_tokens [Integer] Maximum tokens to generate
  # @param temperature [Float] Sampling temperature
  # @raise [NotImplementedError] Always raises - implemented in Phase 4
  def complete(prompt:, max_tokens: 1000, temperature: 0.7)
    raise NotImplementedError,
      "Complete method will be implemented in Phase 4 (Agent Move Generation)"
  end

  private

  # Create Faraday connection with Anthropic headers
  #
  # @return [Faraday::Connection]
  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.headers['x-api-key'] = @api_key
      f.headers['anthropic-version'] = API_VERSION
      f.headers['content-type'] = 'application/json'
      f.adapter Faraday.default_adapter
    end
  end

  # Parse error response from Anthropic API
  #
  # @param response [Faraday::Response] HTTP response
  # @return [Hash] Result with :success false and :message
  def parse_error(response)
    error = response.body&.dig('error') || {}

    case error['type']
    when 'authentication_error'
      { success: false, message: 'Invalid API key. Please check your Anthropic API key.' }
    when 'permission_error'
      { success: false, message: 'Permission denied. Check your API key has access to this model.' }
    when 'rate_limit_error'
      { success: false, message: 'Rate limit exceeded. Please try again later.' }
    else
      message = error['message'] || 'Unknown API error'
      { success: false, message: "API error: #{message}" }
    end
  end
end
