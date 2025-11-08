module Mutations
  class ConfigureOpenaiApi < BaseMutation
    description "Configure OpenAI API credentials and model selection"

    argument :api_key, String, required: true,
      description: "OpenAI API key (starts with 'sk-')"
    argument :model, String, required: true,
      description: "OpenAI model to use"

    field :config, Types::LlmConfigType, null: true,
      description: "The configured LLM settings (null if errors occurred)"
    field :errors, [ String ], null: false,
      description: "Validation errors (empty array if successful)"

    ALLOWED_MODELS = [
      "gpt-4",
      "gpt-4-turbo",
      "gpt-4-turbo-preview",
      "gpt-3.5-turbo",
      "gpt-3.5-turbo-16k"
    ].freeze

    def resolve(api_key:, model:)
      errors = []

      # Validate API key format
      unless api_key.start_with?("sk-")
        errors << "API key must start with 'sk-'"
      end

      # Validate model
      unless ALLOWED_MODELS.include?(model)
        errors << "Model must be one of: #{ALLOWED_MODELS.join(', ')}"
      end

      return { config: nil, errors: errors } if errors.any?

      # Store in session
      LlmConfigService.store(
        context[:session],
        provider: "openai",
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
