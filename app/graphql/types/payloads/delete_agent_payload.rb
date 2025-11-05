module Types
  module Payloads
    class DeleteAgentPayload < Types::BaseObject
      description "Payload returned from deleteAgent mutation"

      field :success, Boolean, null: false,
        description: "Whether the deletion was successful"
      field :errors, [String], null: false,
        description: "Error messages (empty array if successful)"
    end
  end
end
