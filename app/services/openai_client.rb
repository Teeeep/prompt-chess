require 'openai'

class OpenaiClient
  # Initialize OpenAI API client
  #
  # @param session [Hash] Session containing llm_config with api_key and model
  # OR
  # @param api_key [String] OpenAI API key (starts with 'sk-')
  # @param model [String] OpenAI model identifier (e.g., 'gpt-4', 'gpt-3.5-turbo')
  def initialize(session: nil, api_key: nil, model: nil)
    if session
      config = session[:llm_config] || session['llm_config']
      @api_key = config[:api_key] || config['api_key']
      @model = config[:model] || config['model']
    else
      @api_key = api_key
      @model = model
    end
  end

  # Test API connection by making minimal API call
  #
  # @return [Hash] Result with :success (Boolean) and :message (String)
  def test_connection
    response = client.chat(
      parameters: {
        model: @model,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'Hi' }]
      }
    )

    if response && response['choices']
      { success: true, message: 'Connected successfully to OpenAI API' }
    else
      { success: false, message: 'Unexpected response from OpenAI API' }
    end
  rescue Faraday::UnauthorizedError, OpenAI::Error => e
    parse_error(e)
  rescue Faraday::ConnectionFailed => e
    { success: false, message: "Network error: #{e.message}" }
  rescue Faraday::Error => e
    { success: false, message: "Network error: #{e.message}" }
  end

  # Make completion request to OpenAI API
  #
  # @param prompt [String] User prompt
  # @param max_tokens [Integer] Maximum tokens to generate
  # @param temperature [Float] Sampling temperature
  # @return [Hash] Response with :content (String) and :usage (Hash)
  # @raise [Faraday::Error] On network or API errors
  def complete(prompt:, max_tokens: 1000, temperature: 0.7)
    response = client.chat(
      parameters: {
        model: @model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: [{ role: 'user', content: prompt }]
      }
    )

    if response && response['choices'] && response['choices'][0]
      {
        content: response.dig('choices', 0, 'message', 'content') || '',
        usage: {
          input_tokens: response.dig('usage', 'prompt_tokens') || 0,
          output_tokens: response.dig('usage', 'completion_tokens') || 0,
          total_tokens: response.dig('usage', 'total_tokens') || 0
        }
      }
    else
      raise Faraday::Error, 'Unexpected response structure from OpenAI API'
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    raise
  rescue OpenAI::Error => e
    error_result = parse_openai_error(e)
    raise Faraday::Error, error_result[:message]
  end

  private

  # Get OpenAI client instance
  #
  # @return [OpenAI::Client]
  def client
    @client ||= OpenAI::Client.new(access_token: @api_key)
  end

  # Parse error from exception
  #
  # @param error [Exception] Error exception
  # @return [Hash] Result with :success false and :message
  def parse_error(error)
    case error
    when Faraday::UnauthorizedError, OpenAI::Error
      parse_openai_error(error)
    else
      { success: false, message: "Error: #{error.message}" }
    end
  end

  # Parse OpenAI-specific error
  #
  # @param error [OpenAI::Error] OpenAI API error
  # @return [Hash] Result with :success false and :message
  def parse_openai_error(error)
    message = error.message

    if message.include?('Incorrect API key') || message.include?('invalid_api_key') || message.include?('401')
      { success: false, message: 'Invalid API key. Please check your OpenAI API key.' }
    elsif message.include?('insufficient_quota')
      { success: false, message: 'Insufficient quota. Please check your OpenAI account billing.' }
    elsif message.include?('rate_limit')
      { success: false, message: 'Rate limit exceeded. Please try again later.' }
    elsif message.include?('model_not_found')
      { success: false, message: 'Model not found. Please check your model name.' }
    else
      { success: false, message: "API error: #{message}" }
    end
  end
end
