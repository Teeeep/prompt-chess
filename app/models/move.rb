class Move < ApplicationRecord
  belongs_to :match

  enum :player, { agent: 0, stockfish: 1 }, prefix: true, scopes: true

  validates :move_number, presence: true,
                          numericality: { greater_than: 0 },
                          uniqueness: { scope: :match_id }
  validates :move_notation, presence: true
  validates :board_state_before, presence: true
  validates :board_state_after, presence: true
  validates :response_time_ms, presence: true,
                                numericality: { greater_than_or_equal_to: 0 }
end
