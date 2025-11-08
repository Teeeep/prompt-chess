class MoveSerializer
  def initialize(move)
    @move = move
  end

  def as_json
    {
      id: @move.id,
      move_number: @move.move_number,
      player: @move.player,
      move_notation: @move.move_notation,
      board_state_after: @move.board_state_after,
      created_at: @move.created_at.iso8601
    }
  end
end
