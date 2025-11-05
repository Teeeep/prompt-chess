module Types
  class MovePlayerEnum < Types::BaseEnum
    description "Which player made a move"

    value "AGENT", "Agent's move", value: "agent"
    value "STOCKFISH", "Stockfish's move", value: "stockfish"
  end
end
