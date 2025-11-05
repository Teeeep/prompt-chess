module Types
  module Inputs
    class UpdateAgentInput < Types::BaseInputObject
      description "Input for updating an existing agent"

      argument :id, ID, required: true
      argument :name, String, required: false
      argument :role, String, required: false
      argument :prompt_text, String, required: false
      argument :configuration, GraphQL::Types::JSON, required: false
    end
  end
end
