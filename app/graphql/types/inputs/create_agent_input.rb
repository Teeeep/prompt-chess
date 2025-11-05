module Types
  module Inputs
    class CreateAgentInput < Types::BaseInputObject
      description "Input for creating a new agent"

      argument :name, String, required: true
      argument :role, String, required: false
      argument :prompt_text, String, required: true
      argument :configuration, GraphQL::Types::JSON, required: false
    end
  end
end
