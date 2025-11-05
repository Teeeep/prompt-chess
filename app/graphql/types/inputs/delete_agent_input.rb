module Types
  module Inputs
    class DeleteAgentInput < Types::BaseInputObject
      description "Input for deleting an agent"

      argument :id, ID, required: true
    end
  end
end
