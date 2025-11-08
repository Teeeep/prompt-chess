require 'rails_helper'

RSpec.describe MatchRunner do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1, status: :pending) }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: ENV['ANTHROPIC_API_KEY'] || 'test-key', model: 'claude-3-5-haiku-20241022' } } }

  describe '#initialize' do
    it 'creates runner with match and session' do
      runner = MatchRunner.new(match: match, session: session)
      expect(runner).to be_a(MatchRunner)
    end

    it 'raises error without match' do
      expect {
        MatchRunner.new(match: nil, session: session)
      }.to raise_error(ArgumentError, /match is required/)
    end

    it 'raises error without session' do
      expect {
        MatchRunner.new(match: match, session: nil)
      }.to raise_error(ArgumentError, /session is required/)
    end

    it 'initializes validator with starting position' do
      runner = MatchRunner.new(match: match, session: session)
      expect(runner.instance_variable_get(:@validator).current_fen).to eq(MoveValidator::STARTING_FEN)
    end
  end

  describe '#run!', :vcr do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    context 'successful game completion' do
      it 'updates match status to in_progress', vcr: { cassette_name: 'match_runner/full_game' } do
        # Stub to play only 2 moves each
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.status).to eq('completed')
        expect(match.started_at).to be_present
        expect(match.completed_at).to be_present
      end

      it 'creates Move records for each move', vcr: { cassette_name: 'match_runner/move_creation' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        expect {
          runner.run!
        }.to change { match.moves.count }.by_at_least(4)

        # Check move sequence
        moves = match.moves.order(:move_number)
        expect(moves.first.player).to eq('agent')
        expect(moves.second.player).to eq('stockfish')
      end

      it 'alternates between agent and stockfish', vcr: { cassette_name: 'match_runner/alternation' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        moves = match.moves.order(:move_number)
        expect(moves[0].player).to eq('agent')
        expect(moves[1].player).to eq('stockfish')
        expect(moves[2].player).to eq('agent')
        expect(moves[3].player).to eq('stockfish')
      end

      it 'saves LLM data for agent moves', vcr: { cassette_name: 'match_runner/agent_move_data' } do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        agent_move = match.moves.where(player: :agent).first
        expect(agent_move.llm_prompt).to be_present
        expect(agent_move.llm_response).to be_present
        expect(agent_move.tokens_used).to be > 0
      end

      it 'does not save LLM data for stockfish moves', vcr: { cassette_name: 'match_runner/stockfish_move_data' } do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        stockfish_move = match.moves.where(player: :stockfish).first
        expect(stockfish_move.llm_prompt).to be_nil
        expect(stockfish_move.llm_response).to be_nil
        expect(stockfish_move.tokens_used).to be_nil
      end

      it 'updates match total_moves counter', vcr: { cassette_name: 'match_runner/total_moves' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.total_moves).to eq(4)
      end

      it 'accumulates total_tokens_used', vcr: { cassette_name: 'match_runner/total_tokens' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.total_tokens_used).to be > 0
      end
    end

    context 'game ending conditions' do
      it 'detects checkmate and sets winner', vcr: { cassette_name: 'match_runner/checkmate' } do
        # Fool's Mate position (fastest checkmate)
        allow(runner).to receive(:play_turn).and_wrap_original do |method, *args|
          method.call(*args)
          # After 4 moves, should be checkmate
          runner.instance_variable_get(:@validator).apply_move('f3') if match.moves.count == 0
          runner.instance_variable_get(:@validator).apply_move('e5') if match.moves.count == 1
          runner.instance_variable_get(:@validator).apply_move('g4') if match.moves.count == 2
          runner.instance_variable_get(:@validator).apply_move('Qh4') if match.moves.count == 3
        end

        runner.run!

        match.reload
        expect(match.status).to eq('completed')
        expect(match.result_reason).to eq('checkmate')
        expect(match.winner).to be_present
      end

      it 'sets final_board_state on completion', vcr: { cassette_name: 'match_runner/final_board_state' } do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        match.reload
        expect(match.final_board_state).to be_present
        expect(match.final_board_state).to match(/^[rnbqkpRNBQKP1-8\/]+/) # FEN format
      end
    end
  end

  describe '#play_turn' do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    it 'calls AgentMoveService for agent turn', vcr: { cassette_name: 'match_runner/agent_turn' } do
      expect_any_instance_of(AgentMoveService).to receive(:generate_move).and_call_original

      runner.send(:play_turn, player: :agent)
    end

    it 'calls StockfishService for stockfish turn' do
      expect_any_instance_of(StockfishService).to receive(:get_move).and_call_original

      runner.send(:play_turn, player: :stockfish)
    end

    it 'creates Move record with correct player', vcr: { cassette_name: 'match_runner/create_move' } do
      expect {
        runner.send(:play_turn, player: :agent)
      }.to change { match.moves.where(player: :agent).count }.by(1)
    end

    it 'stores board states before and after move', vcr: { cassette_name: 'match_runner/board_states' } do
      runner.send(:play_turn, player: :agent)

      move = match.moves.last
      expect(move.board_state_before).to eq(MoveValidator::STARTING_FEN)
      expect(move.board_state_after).not_to eq(MoveValidator::STARTING_FEN)
    end
  end

  describe 'error handling' do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    context 'when agent fails to produce valid move' do
      it 'marks match as errored' do
        allow_any_instance_of(AgentMoveService).to receive(:generate_move).and_raise(
          AgentMoveService::InvalidMoveError, 'Failed after 3 attempts'
        )

        expect {
          runner.run!
        }.to raise_error(AgentMoveService::InvalidMoveError)

        match.reload
        expect(match.status).to eq('errored')
        expect(match.error_message).to include('Failed after 3 attempts')
      end
    end

    context 'when Stockfish crashes' do
      it 'marks match as errored' do
        # Agent goes first, so we need to let it make one move
        allow_any_instance_of(AgentMoveService).to receive(:generate_move).and_return({
          move: 'e4',
          prompt: 'test prompt',
          response: 'test response',
          tokens: 100,
          time_ms: 500
        })

        # Then Stockfish crashes on its turn
        allow_any_instance_of(StockfishService).to receive(:get_move).and_raise(
          StockfishService::StockfishError, 'Process died'
        )

        expect {
          runner.run!
        }.to raise_error(StockfishService::StockfishError)

        match.reload
        expect(match.status).to eq('errored')
        expect(match.error_message).to include('Process died')
      end
    end
  end
end
