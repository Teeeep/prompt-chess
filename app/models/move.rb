class Move < ApplicationRecord
  belongs_to :match, counter_cache: :total_moves

  enum :player, { agent: 0, stockfish: 1 }, prefix: true, scopes: true

  validates :move_number, presence: true,
                          numericality: { greater_than: 0 },
                          uniqueness: { scope: :match_id }
  validates :move_notation, presence: true
  validates :board_state_before, presence: true
  validates :board_state_after, presence: true
  validates :response_time_ms, presence: true,
                                numericality: { greater_than_or_equal_to: 0 }

  after_create_commit :broadcast_move

  private

  def broadcast_move
    MatchChannel.broadcast_to(match, {
      type: "move_added",
      move: MoveSerializer.new(self).as_json
    })
  end
end
