module Mutations
  class ConfigureAnthropicApi < BaseMutation
    description "Configure Anthropic API credentials and model selection"

    argument :api_key, String, required: true,
      description: "Anthropic API key (starts with 'sk-ant-')"
    argument :model, String, required: true,
      description: "Claude model to use"

    field :config, Types::LlmConfigType, null: true,
      description: "The configured LLM settings (null if errors occurred)"
    field :errors, [ String ], null: false,
      description: "Validation errors (empty array if successful)"

    ALLOWED_MODELS = [
      # Claude 4 family (latest)
      "claude-haiku-4-5-20251001",
      "claude-sonnet-4-5-20250929",
      "claude-opus-4-1-20250805",
      "claude-opus-4-20250514",
      "claude-sonnet-4-20250514",
      # Claude 3 family
      "claude-3-5-haiku-20241022",
      "claude-3-haiku-20240307"
    ].freeze

    def resolve(api_key:, model:)
      errors = []

      # Validate API key format
      unless api_key.start_with?("sk-ant-")
        errors << "API key must start with 'sk-ant-'"
      end

      # Validate model
      unless ALLOWED_MODELS.include?(model)
        errors << "Model must be one of: #{ALLOWED_MODELS.join(', ')}"
      end

      return { config: nil, errors: errors } if errors.any?

      # Store in session
      LlmConfigService.store(
        context[:session],
        provider: "anthropic",
        api_key: api_key,
        model: model
      )

      # Return config with masked key
      config = LlmConfigService.current(context[:session])
      {
        config: {
          provider: config[:provider],
          model: config[:model],
          api_key_last_four: LlmConfigService.masked_key(context[:session]),
          configured_at: config[:configured_at]
        },
        errors: []
      }
    end
  end
end
