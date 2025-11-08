class AddChessMoveNumberToMoves < ActiveRecord::Migration[8.0]
  def change
    # Add chess_move_number to track the traditional chess move number
    # where white and black moves share the same number (1. e4 e5, 2. Nf3 Nc6, etc.)
    #
    # Examples:
    # - White's first move (e4):    move_number=1, chess_move_number=1
    # - Black's first move (e5):    move_number=2, chess_move_number=1
    # - White's second move (Nf3):  move_number=3, chess_move_number=2
    # - Black's second move (Nc6):  move_number=4, chess_move_number=2
    add_column :moves, :chess_move_number, :integer, null: false, default: 1
  end
end
