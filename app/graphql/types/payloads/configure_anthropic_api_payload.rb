module Types
  module Payloads
    class ConfigureAnthropicApiPayload < Types::BaseObject
      description "Payload returned from configureAnthropicApi mutation"

      field :config, Types::LlmConfigType, null: true,
        description: "The configured LLM settings (null if errors occurred)"

      field :errors, [String], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
