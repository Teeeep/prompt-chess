module Mutations
  class TestApiConnection < BaseMutation
    description "Test the configured API connection"

    field :success, Boolean, null: false,
      description: "Whether the connection test succeeded"
    field :message, String, null: false,
      description: "Human-readable result message"
    field :errors, [String], null: false,
      description: "Error messages (empty array if successful)"

    def resolve
      config = LlmConfigService.current(context[:session])

      unless config
        return {
          success: false,
          message: 'No API configuration found',
          errors: ['Please configure your API credentials first']
        }
      end

      # Test connection based on provider
      # Handle both symbol and string keys (session serialization)
      provider = config[:provider] || config['provider']
      api_key = config[:api_key] || config['api_key']
      model = config[:model] || config['model']

      result = case provider
      when 'anthropic'
        client = AnthropicClient.new(
          api_key: api_key,
          model: model
        )
        client.test_connection
      when 'openai'
        client = OpenaiClient.new(
          api_key: api_key,
          model: model
        )
        client.test_connection
      else
        { success: false, message: "Unknown provider: #{provider}" }
      end

      {
        success: result[:success],
        message: result[:message],
        errors: result[:success] ? [] : [result[:message]]
      }
    end
  end
end
