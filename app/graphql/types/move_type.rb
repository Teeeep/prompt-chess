module Types
  class MoveType < Types::BaseObject
    description "A single move in a chess match"

    field :id, ID, null: false
    field :move_number, Integer, null: false,
      description: "Sequential ply number (1, 2, 3, 4...)"
    field :chess_move_number, Integer, null: false,
      description: "Traditional chess move number where white and black share the same number (1, 1, 2, 2...)"
    field :player, Types::MovePlayerEnum, null: false
    field :move_notation, String, null: false,
      description: "Move in standard algebraic notation (e.g., e4, Nf3, O-O)"

    field :board_state_before, String, null: false,
      description: "Position before move in FEN notation"
    field :board_state_after, String, null: false,
      description: "Position after move in FEN notation"

    field :llm_prompt, String, null: true,
      description: "Full prompt sent to LLM (agent moves only)"
    field :llm_response, String, null: true,
      description: "Raw LLM response (agent moves only)"
    field :tokens_used, Integer, null: true,
      description: "Tokens consumed by this move (agent moves only)"

    field :response_time_ms, Integer, null: false,
      description: "Time taken to generate this move in milliseconds"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
