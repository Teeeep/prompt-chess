module Types
  module Payloads
    class TestApiConnectionPayload < Types::BaseObject
      description "Payload returned from testApiConnection mutation"

      field :success, Boolean, null: false,
        description: "Whether the connection test succeeded"

      field :message, String, null: false,
        description: "Human-readable result message"

      field :errors, [String], null: false,
        description: "Error messages (empty array if successful)"
    end
  end
end
