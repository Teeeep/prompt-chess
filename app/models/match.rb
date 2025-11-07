class Match < ApplicationRecord
  belongs_to :agent
  has_many :moves, -> { order(:move_number) }, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, errored: 3 }, prefix: true
  enum :winner, { agent: 0, stockfish: 1, draw: 2 }, prefix: true

  validates :stockfish_level, inclusion: { in: 1..8 }
  validates :status, presence: true
  validates :total_moves, numericality: { greater_than_or_equal_to: 0 }
  validates :total_tokens_used, numericality: { greater_than_or_equal_to: 0 }
  validates :total_cost_cents, numericality: { greater_than_or_equal_to: 0 }

  # Override total_moves to use counter cache
  def total_moves
    moves_count
  end
end
