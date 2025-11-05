module Types
  class MatchType < Types::BaseObject
    description "A chess match between an agent and Stockfish"

    field :id, ID, null: false
    field :agent, Types::AgentType, null: false
    field :stockfish_level, Integer, null: false,
      description: "Stockfish difficulty level (1-8)"

    field :status, Types::MatchStatusEnum, null: false
    field :winner, Types::MatchWinnerEnum, null: true
    field :result_reason, String, null: true,
      description: "How the game ended (checkmate, stalemate, etc.)"

    field :started_at, GraphQL::Types::ISO8601DateTime, null: true
    field :completed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :total_moves, Integer, null: false
    field :opening_name, String, null: true

    field :total_tokens_used, Integer, null: false
    field :total_cost_cents, Integer, null: false,
      description: "Estimated API cost in cents"
    field :average_move_time_ms, Integer, null: true,
      description: "Average time per move in milliseconds"
    field :final_board_state, String, null: true,
      description: "Final position in FEN notation"

    field :error_message, String, null: true

    field :moves, [Types::MoveType], null: false

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
