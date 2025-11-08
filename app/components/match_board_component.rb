class MatchBoardComponent < ViewComponent::Base
  STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  def initialize(match:)
    @match = match
  end

  def board_fen
    @match.moves.any? ? @match.moves.last.board_state_after : STARTING_FEN
  end
end
