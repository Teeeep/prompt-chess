module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :match_updated, Types::MatchUpdatePayloadType, null: false,
      description: "Subscribe to real-time updates for a match" do
      argument :match_id, ID, required: true
    end

    def match_updated(match_id:)
      # Subscription is triggered by MatchRunner broadcasting
      # No implementation needed here - GraphQL handles it
    end
  end
end
