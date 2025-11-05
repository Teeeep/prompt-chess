module Types
  module Inputs
    class ConfigureAnthropicApiInput < Types::BaseInputObject
      description "Input for configuring Anthropic API"

      argument :api_key, String, required: true,
        description: "Anthropic API key (starts with 'sk-ant-')"

      argument :model, String, required: true,
        description: "Claude model to use"
    end
  end
end
