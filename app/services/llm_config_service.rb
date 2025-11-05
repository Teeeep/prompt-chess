class LlmConfigService
  # Store LLM configuration in Rails session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @param provider [String] LLM provider name (e.g., 'anthropic')
  # @param api_key [String] API key for the provider
  # @param model [String] Model identifier (e.g., 'claude-3-5-sonnet-20241022')
  def self.store(session, provider:, api_key:, model:)
    session[:llm_config] = {
      provider: provider,
      api_key: api_key,
      model: model,
      configured_at: Time.current
    }
  end

  # Retrieve current LLM configuration from session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [Hash, nil] Configuration hash or nil if not configured
  def self.current(session)
    session[:llm_config]
  end

  # Get masked API key showing only last 4 characters
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [String, nil] Masked key (e.g., "...Ab3d") or nil if not configured
  def self.masked_key(session)
    config = current(session)
    return nil unless config

    # Handle both symbol and string keys (session serialization converts symbols to strings)
    key = config[:api_key] || config["api_key"]
    "...#{key[-4..]}"
  end

  # Clear LLM configuration from session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  def self.clear(session)
    session.delete(:llm_config)
  end

  # Check if LLM is configured in session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [Boolean] true if configured, false otherwise
  def self.configured?(session)
    current(session).present?
  end
end
