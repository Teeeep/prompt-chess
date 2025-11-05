require 'rails_helper'

RSpec.describe 'Chess Services Integration', :stockfish, type: :integration do
  describe 'MoveValidator + StockfishService' do
    it 'can play a short game between validator and engine' do
      validator = MoveValidator.new
      stockfish = StockfishService.new(level: 1)

      moves_played = []

      # Play 3 moves each
      6.times do |i|
        current_fen = validator.current_fen

        # Get Stockfish's move
        result = stockfish.get_move(current_fen)
        move = result[:move]

        # Validate and apply the move
        expect(validator.valid_move?(move)).to be true
        validator.apply_move(move)

        moves_played << move
      end

      expect(moves_played.length).to eq(6)
      expect(validator.game_over?).to be false # Game still ongoing

      stockfish.close
    end

    it 'stockfish only suggests legal moves' do
      stockfish = StockfishService.new(level: 3)

      # Test multiple positions
      positions = [
        MoveValidator::STARTING_FEN,
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3'
      ]

      positions.each do |fen|
        validator = MoveValidator.new(fen: fen)
        result = stockfish.get_move(fen)

        expect(validator.legal_moves).to include(result[:move]),
          "Stockfish suggested illegal move #{result[:move]} for position #{fen}"
      end

      stockfish.close
    end
  end
end
