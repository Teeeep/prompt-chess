require "rails_helper"

RSpec.describe StockfishResponseJob, type: :job do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, status: :in_progress, stockfish_level: 1) }
  let!(:first_move) do
    create(:move, :agent_move,
           match: match,
           move_number: 1,
           move_notation: "e4",
           board_state_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  end

  describe "#perform" do
    it "creates a stockfish move" do
      expect {
        described_class.new.perform(match.id)
      }.to change { match.moves.count }.by(1)

      stockfish_move = match.moves.last
      expect(stockfish_move.player).to eq("stockfish")
      expect(stockfish_move.move_number).to eq(2)
      expect(stockfish_move.move_notation).to be_present
    end

    it "broadcasts the move via ActionCable" do
      expect(MatchChannel).to receive(:broadcast_to).with(
        match,
        hash_including(type: "move_added")
      )

      described_class.new.perform(match.id)
    end

    context "when game ends in checkmate" do
      let!(:setup_moves) do
        # Set up position where Stockfish's next move will deliver checkmate
        # We'll use a simpler setup where we control the moves
        match.moves.destroy_all
        # Position after e4 e5 Qh5 Nc6 Bc4 Nf6
        create(:move, :agent_move, match: match, move_number: 1,
               move_notation: "e4",
               board_state_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
        create(:move, :stockfish_move, match: match, move_number: 2,
               move_notation: "e5",
               board_state_after: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2")
        create(:move, :agent_move, match: match, move_number: 3,
               move_notation: "Qh5",
               board_state_after: "rnbqkbnr/pppp1ppp/8/4p2Q/4P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2")
        create(:move, :stockfish_move, match: match, move_number: 4,
               move_notation: "Nc6",
               board_state_after: "r1bqkbnr/pppp1ppp/2n5/4p2Q/4P3/8/PPPP1PPP/RNBQK1NR w KQkq - 2 3")
        create(:move, :agent_move, match: match, move_number: 5,
               move_notation: "Bc4",
               board_state_after: "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 3 3")
        # Now it's stockfish's turn and after Nf6, the agent will have a checkmate
        # But we need stockfish to make a move that DELIVERS checkmate
        # Let's set up so stockfish makes the final move
        create(:move, :stockfish_move, match: match, move_number: 6,
               move_notation: "Nf6",
               board_state_after: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
        # Agent moves
        create(:move, :agent_move, match: match, move_number: 7,
               move_notation: "Qxf7",
               board_state_after: "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4")
      end

      it "marks match as completed and sets winner" do
        # Mock the validator to detect checkmate
        validator = instance_double(MoveValidator)
        allow(MoveValidator).to receive(:new).and_return(validator)
        allow(validator).to receive(:apply_move).and_return("some_fen_after_move")
        allow(validator).to receive(:game_over?).and_return(true)
        allow(validator).to receive(:result).and_return("checkmate")

        # Stockfish makes any legal move
        allow(StockfishService).to receive(:get_move).and_return("Kd8")

        described_class.new.perform(match.id)

        match.reload
        expect(match.status).to eq("completed")
        expect(match.winner).to eq("stockfish")
      end
    end

    context "when game ends in stalemate" do
      # Simplified stalemate test - just verify the detection works
      it "marks match as draw" do
        # Mock the validator to return stalemate
        validator = instance_double(MoveValidator)
        allow(MoveValidator).to receive(:new).and_return(validator)
        allow(validator).to receive(:apply_move).and_return("some_fen")
        allow(validator).to receive(:game_over?).and_return(true)
        allow(validator).to receive(:result).and_return("stalemate")

        allow(StockfishService).to receive(:get_move).and_return("Kh1")

        described_class.new.perform(match.id)

        match.reload
        expect(match.status).to eq("completed")
        expect(match.winner).to eq("draw")
      end
    end

    context "when Stockfish times out" do
      it "retries up to 3 times" do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::TimeoutError.new("Timeout"))

        perform_enqueued_jobs do
          described_class.perform_later(match.id)
        rescue StockfishService::TimeoutError
          # Expected to raise after retries exhausted
        end

        # Verify it attempted retries (ActiveJob will retry automatically)
        expect(StockfishService).to have_received(:get_move).exactly(3).times
      end
    end

    context "when Stockfish crashes" do
      it "retries up to 2 times" do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::EngineError.new("Crash"))

        perform_enqueued_jobs do
          described_class.perform_later(match.id)
        rescue StockfishService::EngineError
          # Expected to raise after retries exhausted
        end

        # Verify it attempted retries (ActiveJob will retry automatically)
        expect(StockfishService).to have_received(:get_move).exactly(2).times
      end
    end

    context "when retries are exhausted" do
      before do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::TimeoutError.new("Timeout"))
      end

      it "marks match as errored" do
        perform_enqueued_jobs do
          described_class.perform_later(match.id)
        rescue StockfishService::TimeoutError
          # Expected to raise after retries
        end

        match.reload
        expect(match.status).to eq("errored")
      end

      it "broadcasts error message" do
        expect(MatchChannel).to receive(:broadcast_to).with(
          match,
          hash_including(type: "error")
        )

        perform_enqueued_jobs do
          described_class.perform_later(match.id)
        rescue StockfishService::TimeoutError
          # Expected
        end
      end
    end
  end
end
