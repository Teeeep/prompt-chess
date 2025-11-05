module Types
  class AgentType < Types::BaseObject
    description "A chess-playing agent with a custom prompt"

    field :id, ID, null: false
    field :name, String, null: false
    field :role, String, null: true
    field :prompt_text, String, null: false
    field :configuration, GraphQL::Types::JSON, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
