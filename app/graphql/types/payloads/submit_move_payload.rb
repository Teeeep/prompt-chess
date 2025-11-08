module Types
  module Payloads
    class SubmitMovePayload < Types::BaseObject
      field :success, Boolean, null: false,
        description: "Whether the move submission was successful"
      field :move, Types::MoveType, null: true,
        description: "The created move if successful"
      field :error, String, null: true,
        description: "Error message if unsuccessful"
    end
  end
end
