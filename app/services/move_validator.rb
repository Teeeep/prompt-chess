class MoveValidator
  class IllegalMoveError < StandardError; end

  # Starting position FEN
  STARTING_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'

  attr_reader :current_fen

  def initialize(fen: nil)
    @game = fen ? Chess::Game.load_fen(fen) : Chess::Game.new
    @current_fen = @game.board.to_fen
  end

  # Check if a move is legal in current position
  def valid_move?(move_san)
    return false if move_san.nil? || move_san.empty?

    # Check if move is in legal moves list
    legal_moves.include?(move_san)
  rescue
    false
  end

  # Get all legal moves in current position
  def legal_moves
    @game.board.generate_all_moves
  end

  # Apply a move and update position
  # Returns new FEN string
  # Raises IllegalMoveError if move is invalid
  def apply_move(move_san)
    begin
      @game.move(move_san)
      @current_fen = @game.board.to_fen
      @current_fen
    rescue Chess::IllegalMoveError, Chess::BadNotationError => e
      raise IllegalMoveError, "Illegal move: #{move_san}"
    end
  end

  # Check if game is over (checkmate or stalemate)
  def game_over?
    @game.over?
  end

  # Check if current position is checkmate
  def checkmate?
    @game.board.checkmate?
  end

  # Check if current position is stalemate
  def stalemate?
    @game.board.stalemate?
  end

  # Get game result
  # Returns: 'checkmate', 'stalemate', or nil
  def result
    return 'checkmate' if checkmate?
    return 'stalemate' if stalemate?
    nil
  end
end
