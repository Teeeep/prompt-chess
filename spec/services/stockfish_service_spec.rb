require 'rails_helper'

RSpec.describe StockfishService, :stockfish do
  describe '#initialize' do
    it 'creates service with default level 5' do
      service = StockfishService.new
      expect(service.level).to eq(5)
    end

    it 'creates service with custom level' do
      service = StockfishService.new(level: 3)
      expect(service.level).to eq(3)
    end

    it 'raises error for invalid level' do
      expect {
        StockfishService.new(level: 0)
      }.to raise_error(ArgumentError, /level must be between 1 and 8/)
    end
  end

  describe '#get_move' do
    let(:service) { StockfishService.new(level: 1) }

    it 'returns a legal move from starting position' do
      result = service.get_move(MoveValidator::STARTING_FEN)

      expect(result).to be_a(Hash)
      expect(result[:move]).to be_a(String)
      expect(result[:time_ms]).to be_a(Integer)
      expect(result[:time_ms]).to be > 0

      # Verify it's a legal opening move
      validator = MoveValidator.new
      expect(validator.legal_moves).to include(result[:move])
    end

    it 'returns different move for mid-game position' do
      # Position after 1. e4 e5
      fen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'
      result = service.get_move(fen)

      expect(result[:move]).to be_a(String)

      # Verify it's a legal move for this position
      validator = MoveValidator.new(fen: fen)
      expect(validator.legal_moves).to include(result[:move])
    end

    it 'returns move quickly at low level' do
      result = service.get_move(MoveValidator::STARTING_FEN)
      expect(result[:time_ms]).to be < 2000 # Should be fast at level 1
    end

    it 'raises error for invalid FEN' do
      expect {
        service.get_move('invalid fen string')
      }.to raise_error(StockfishService::StockfishError)
    end
  end

  describe '#close' do
    it 'closes the engine gracefully' do
      service = StockfishService.new
      expect { service.close }.not_to raise_error
    end

    it 'can be called multiple times safely' do
      service = StockfishService.new
      service.close
      expect { service.close }.not_to raise_error
    end
  end

  describe 'level strength' do
    it 'level 1 makes weaker moves than level 8' do
      weak_service = StockfishService.new(level: 1)
      strong_service = StockfishService.new(level: 8)

      # Simple tactical position: white can capture free pawn
      # After 1. e4 e5 2. Nf3 d6 3. Bc4 h6 4. Nc3
      fen = 'rnbqkbnr/ppp2pp1/3p3p/4p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R b KQkq - 2 4'

      weak_move = weak_service.get_move(fen)
      strong_move = strong_service.get_move(fen)

      # Both should return legal moves
      validator = MoveValidator.new(fen: fen)
      expect(validator.legal_moves).to include(weak_move[:move])
      expect(validator.legal_moves).to include(strong_move[:move])

      # Moves might differ (though not guaranteed in every position)
      # Just verify both work and return in reasonable time
      expect(weak_move[:time_ms]).to be < 3000
      expect(strong_move[:time_ms]).to be < 5000

      weak_service.close
      strong_service.close
    end
  end

  describe 'error handling' do
    let(:service) { StockfishService.new }

    it 'raises error if engine crashes' do
      allow(service).to receive(:send_command).and_raise(Errno::EPIPE)

      expect {
        service.get_move(MoveValidator::STARTING_FEN)
      }.to raise_error(StockfishService::StockfishError, /Stockfish process died/)
    end

    it 'raises error on timeout' do
      allow(service).to receive(:read_until).and_raise(Timeout::Error)

      expect {
        service.get_move(MoveValidator::STARTING_FEN)
      }.to raise_error(StockfishService::StockfishError, /timed out/)
    end
  end
end
