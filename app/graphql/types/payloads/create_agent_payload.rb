module Types
  module Payloads
    class CreateAgentPayload < Types::BaseObject
      description "Payload returned from createAgent mutation"

      field :agent, Types::AgentType, null: true,
        description: "The created agent (null if errors occurred)"
      field :errors, [ String ], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
