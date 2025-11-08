module Types
  class MatchUpdatePayloadType < Types::BaseObject
    description "Payload for match update subscription"

    field :match, Types::MatchType, null: false,
      description: "Updated match state"
    field :latest_move, Types::MoveType, null: true,
      description: "The move that was just played"
  end
end
