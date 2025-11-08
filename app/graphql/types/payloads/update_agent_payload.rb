module Types
  module Payloads
    class UpdateAgentPayload < Types::BaseObject
      description "Payload returned from updateAgent mutation"

      field :agent, Types::AgentType, null: true,
        description: "The updated agent (null if errors occurred)"
      field :errors, [ String ], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
