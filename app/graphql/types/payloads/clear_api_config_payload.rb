module Types
  module Payloads
    class ClearApiConfigPayload < Types::BaseObject
      description "Payload returned from clearApiConfig mutation"

      field :success, Boolean, null: false,
        description: "Whether the configuration was cleared"
    end
  end
end
