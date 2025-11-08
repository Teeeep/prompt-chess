require "faraday"

class AnthropicClient
  BASE_URL = "https://api.anthropic.com/v1/"
  API_VERSION = "2023-06-01"

  # Initialize Anthropic API client
  #
  # @param session [Hash] Session containing llm_config with api_key and model
  # OR
  # @param api_key [String] Anthropic API key (starts with 'sk-ant-')
  # @param model [String] Claude model identifier
  def initialize(session: nil, api_key: nil, model: nil)
    if session
      config = session[:llm_config] || session["llm_config"]
      @api_key = config[:api_key] || config["api_key"]
      @model = config[:model] || config["model"]
    else
      @api_key = api_key
      @model = model
    end
  end

  # Test API connection by making minimal API call
  #
  # @return [Hash] Result with :success (Boolean) and :message (String)
  def test_connection
    response = connection.post("messages") do |req|
      req.body = {
        model: @model,
        max_tokens: 10,
        messages: [ { role: "user", content: "Hi" } ]
      }
    end

    if response.success?
      { success: true, message: "Connected successfully to Anthropic API" }
    else
      parse_error(response)
    end
  rescue Faraday::ConnectionFailed => e
    { success: false, message: "Network error: #{e.message}" }
  rescue Faraday::Error => e
    { success: false, message: "Network error: #{e.message}" }
  end

  # Make completion request to Anthropic API
  #
  # @param prompt [String] User prompt
  # @param max_tokens [Integer] Maximum tokens to generate
  # @param temperature [Float] Sampling temperature
  # @return [Hash] Response with :content (String) and :usage (Hash)
  # @raise [Faraday::Error] On network or API errors
  def complete(prompt:, max_tokens: 1000, temperature: 0.7)
    response = connection.post("messages") do |req|
      req.body = {
        model: @model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: [ { role: "user", content: prompt } ]
      }
    end

    if response.success?
      {
        content: response.body.dig("content", 0, "text") || "",
        usage: {
          input_tokens: response.body.dig("usage", "input_tokens") || 0,
          output_tokens: response.body.dig("usage", "output_tokens") || 0,
          total_tokens: (response.body.dig("usage", "input_tokens") || 0) + (response.body.dig("usage", "output_tokens") || 0)
        }
      }
    else
      error_result = parse_error(response)
      raise Faraday::Error, error_result[:message]
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    raise
  end

  private

  # Create Faraday connection with Anthropic headers
  #
  # @return [Faraday::Connection]
  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.headers["x-api-key"] = @api_key
      f.headers["anthropic-version"] = API_VERSION
      f.headers["content-type"] = "application/json"
      f.adapter Faraday.default_adapter
    end
  end

  # Parse error response from Anthropic API
  #
  # @param response [Faraday::Response] HTTP response
  # @return [Hash] Result with :success false and :message
  def parse_error(response)
    error = response.body&.dig("error") || {}

    case error["type"]
    when "authentication_error"
      { success: false, message: "Invalid API key. Please check your Anthropic API key." }
    when "permission_error"
      { success: false, message: "Permission denied. Check your API key has access to this model." }
    when "rate_limit_error"
      { success: false, message: "Rate limit exceeded. Please try again later." }
    else
      message = error["message"] || "Unknown API error"
      { success: false, message: "API error: #{message}" }
    end
  end
end
