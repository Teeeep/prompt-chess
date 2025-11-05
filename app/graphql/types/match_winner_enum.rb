module Types
  class MatchWinnerEnum < Types::BaseEnum
    description "Winner of a chess match"

    value "AGENT", "Agent won", value: "agent"
    value "STOCKFISH", "Stockfish won", value: "stockfish"
    value "DRAW", "Game was a draw", value: "draw"
  end
end
