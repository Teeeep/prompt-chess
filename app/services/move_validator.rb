class MoveValidator
  class IllegalMoveError < StandardError; end

  attr_reader :current_fen

  def initialize(fen: nil)
    @game = fen ? Chess::Game.load_fen(fen) : Chess::Game.new
    @current_fen = @game.fen
  end

  # Check if a move is legal in current position
  def valid_move?(move_san)
    return false if move_san.nil? || move_san.empty?

    # Try to find the move in legal moves
    legal_moves.include?(move_san)
  rescue
    false
  end

  # Get all legal moves in current position
  def legal_moves
    @game.moves
  end

  # Apply a move and update position
  # Returns new FEN string
  # Raises IllegalMoveError if move is invalid
  def apply_move(move_san)
    unless valid_move?(move_san)
      raise IllegalMoveError, "Illegal move: #{move_san}"
    end

    @game.move(move_san)
    @current_fen = @game.fen
  end

  # Check if game is over (checkmate or stalemate)
  def game_over?
    @game.over?
  end

  # Check if current position is checkmate
  def checkmate?
    @game.checkmate?
  end

  # Check if current position is stalemate
  def stalemate?
    @game.stalemate?
  end

  # Get game result
  # Returns: 'checkmate', 'stalemate', or nil
  def result
    return 'checkmate' if checkmate?
    return 'stalemate' if stalemate?
    nil
  end
end
