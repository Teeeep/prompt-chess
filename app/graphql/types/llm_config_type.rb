module Types
  class LlmConfigType < Types::BaseObject
    description "Current LLM API configuration for the session"

    field :provider, String, null: false,
      description: "LLM provider name (e.g., 'anthropic')"

    field :model, String, null: false,
      description: "Selected model (e.g., 'claude-3-5-sonnet-20241022')"

    field :api_key_last_four, String, null: false,
      description: "Last 4 characters of API key for verification"

    field :configured_at, GraphQL::Types::ISO8601DateTime, null: false,
      description: "When this configuration was set"
  end
end
