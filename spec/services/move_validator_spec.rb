require 'rails_helper'

RSpec.describe MoveValidator do
  describe '#initialize' do
    it 'creates validator with starting position' do
      validator = MoveValidator.new
      expect(validator.current_fen).to eq(MoveValidator::STARTING_FEN)
    end

    it 'creates validator with custom FEN' do
      fen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'
      validator = MoveValidator.new(fen: fen)
      expect(validator.current_fen).to eq(fen)
    end
  end

  describe '#valid_move?' do
    let(:validator) { MoveValidator.new }

    it 'returns true for legal opening moves' do
      expect(validator.valid_move?('e4')).to be true
      expect(validator.valid_move?('d4')).to be true
      expect(validator.valid_move?('Nf3')).to be true
    end

    it 'returns false for illegal moves' do
      expect(validator.valid_move?('e5')).to be false # Black's move on white's turn
      expect(validator.valid_move?('Ke2')).to be false # King can't move yet
      expect(validator.valid_move?('Ra3')).to be false # Rook blocked by pawn
    end

    it 'returns false for invalid notation' do
      expect(validator.valid_move?('xyz')).to be false
      expect(validator.valid_move?('')).to be false
      expect(validator.valid_move?(nil)).to be false
    end
  end

  describe '#legal_moves' do
    let(:validator) { MoveValidator.new }

    it 'returns all legal moves from starting position' do
      moves = validator.legal_moves
      expect(moves).to include('e4', 'd4', 'Nf3', 'Nc3')
      expect(moves.length).to eq(20) # 16 pawn moves + 4 knight moves
    end

    it 'returns limited moves in restricted position' do
      # Position with only a few legal moves
      fen = 'r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4'
      validator = MoveValidator.new(fen: fen)
      moves = validator.legal_moves
      expect(moves).to be_an(Array)
      expect(moves.length).to be > 0
    end
  end

  describe '#apply_move' do
    let(:validator) { MoveValidator.new }

    it 'applies a legal move and returns new FEN' do
      new_fen = validator.apply_move('e4')
      expect(new_fen).to eq('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')
      expect(validator.current_fen).to eq(new_fen)
    end

    it 'updates legal moves after applying move' do
      validator.apply_move('e4')
      moves = validator.legal_moves
      # Now it's black's turn
      expect(moves).to include('e5', 'd5', 'Nf6', 'Nc6')
      expect(moves).not_to include('e4') # Can't move white pieces
    end

    it 'raises error for illegal move' do
      expect {
        validator.apply_move('e5') # Black's move on white's turn
      }.to raise_error(MoveValidator::IllegalMoveError)
    end

    it 'raises error for invalid notation' do
      expect {
        validator.apply_move('xyz')
      }.to raise_error(MoveValidator::IllegalMoveError)
    end
  end

  describe '#game_over?' do
    it 'returns false for starting position' do
      validator = MoveValidator.new
      expect(validator.game_over?).to be false
    end

    it 'returns true for checkmate position' do
      # Fool's mate position
      fen = 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'
      validator = MoveValidator.new(fen: fen)
      expect(validator.game_over?).to be true
      expect(validator.checkmate?).to be true
    end

    it 'returns true for stalemate position' do
      # Stalemate position
      fen = 'k7/8/1K6/8/8/8/8/1Q6 b - - 0 1'
      validator = MoveValidator.new(fen: fen)
      expect(validator.game_over?).to be true
      expect(validator.stalemate?).to be true
    end
  end

  describe '#result' do
    it 'returns nil for ongoing game' do
      validator = MoveValidator.new
      expect(validator.result).to be_nil
    end

    it 'returns checkmate for checkmated position' do
      fen = 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'
      validator = MoveValidator.new(fen: fen)
      expect(validator.result).to eq('checkmate')
    end

    it 'returns stalemate for stalemated position' do
      fen = 'k7/8/1K6/8/8/8/8/1Q6 b - - 0 1'
      validator = MoveValidator.new(fen: fen)
      expect(validator.result).to eq('stalemate')
    end
  end

  describe 'full game simulation' do
    it 'can play a short game to checkmate' do
      validator = MoveValidator.new

      # Fool's Mate (fastest checkmate)
      validator.apply_move('f3')
      validator.apply_move('e5')
      validator.apply_move('g4')
      validator.apply_move('Qh4')

      expect(validator.checkmate?).to be true
      expect(validator.result).to eq('checkmate')
    end
  end
end
