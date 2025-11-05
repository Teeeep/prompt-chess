require 'rails_helper'

RSpec.describe AgentMoveService do
  let(:agent) { create(:agent, prompt_text: 'You are a tactical chess master.') }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }
  let(:starting_fen) { 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' }
  let(:validator) { instance_double('MoveValidator', current_fen: starting_fen, legal_moves: ['e4', 'd4', 'Nf3', 'c4'], valid_move?: true) }

  describe '#initialize' do
    it 'creates service with required parameters' do
      service = AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )

      expect(service).to be_a(AgentMoveService)
    end

    it 'raises error without agent' do
      expect {
        AgentMoveService.new(
          agent: nil,
          validator: validator,
          move_history: [],
          session: session
        )
      }.to raise_error(ArgumentError, /agent is required/)
    end

    it 'raises error without validator' do
      expect {
        AgentMoveService.new(
          agent: agent,
          validator: nil,
          move_history: [],
          session: session
        )
      }.to raise_error(ArgumentError, /validator is required/)
    end
  end

  describe '#generate_move', :vcr do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'with valid LLM response' do
      it 'returns move data with all fields', vcr: { cassette_name: 'agent_move_service/valid_opening_move' } do
        result = service.generate_move

        expect(result).to be_a(Hash)
        expect(result).to have_key(:move)
        expect(result).to have_key(:prompt)
        expect(result).to have_key(:response)
        expect(result).to have_key(:tokens)
        expect(result).to have_key(:time_ms)

        # Move should be valid
        expect(validator.legal_moves).to include(result[:move])

        # Metadata should be present
        expect(result[:prompt]).to be_a(String)
        expect(result[:prompt].length).to be > 100
        expect(result[:response]).to be_a(String)
        expect(result[:tokens]).to be_a(Integer)
        expect(result[:tokens]).to be > 0
        expect(result[:time_ms]).to be_a(Integer)
        expect(result[:time_ms]).to be > 0
      end
    end

    context 'with move history' do
      # Create mock move objects
      let(:move1) { double('Move', move_number: 1, move_notation: 'e4', player: :agent) }
      let(:move2) { double('Move', move_number: 2, move_notation: 'e5', player: :stockfish) }

      let(:service) do
        validator_with_history = instance_double('MoveValidator')
        allow(validator_with_history).to receive(:current_fen).and_return('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2')
        allow(validator_with_history).to receive(:legal_moves).and_return(['Nf3', 'Nc3', 'Bc4', 'd4'])
        allow(validator_with_history).to receive(:valid_move?).and_return(true)

        AgentMoveService.new(
          agent: agent,
          validator: validator_with_history,
          move_history: [move1, move2],
          session: session
        )
      end

      it 'includes move history in prompt', vcr: { cassette_name: 'agent_move_service/with_move_history' } do
        result = service.generate_move

        expect(result[:prompt]).to include('e4')
        expect(result[:prompt]).to include('e5')
        expect(result[:prompt]).to include('Move History')
      end
    end
  end

  describe '#build_prompt' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    it 'includes agent name and prompt' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include(agent.name)
      expect(prompt).to include(agent.prompt_text)
    end

    it 'includes current position FEN' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include('Current Position (FEN)')
      expect(prompt).to include(starting_fen)
    end

    it 'includes legal moves' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include('Legal moves')
      expect(prompt).to include('e4')
      expect(prompt).to include('d4')
    end

    it 'includes move history when present' do
      move1 = double('Move', move_number: 1, move_notation: 'e4', player: :agent)

      validator_with_history = instance_double('MoveValidator')
      allow(validator_with_history).to receive(:current_fen).and_return('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')
      allow(validator_with_history).to receive(:legal_moves).and_return(['e5', 'd5', 'Nf6', 'c5'])
      allow(validator_with_history).to receive(:valid_move?).and_return(true)

      service = AgentMoveService.new(
        agent: agent,
        validator: validator_with_history,
        move_history: [move1],
        session: session
      )

      prompt = service.send(:build_prompt)
      expect(prompt).to include('Move History')
      expect(prompt).to include('1. e4')
    end

    it 'formats move history in standard notation' do
      move1 = double('Move', move_number: 1, move_notation: 'e4', player: :agent)
      move2 = double('Move', move_number: 2, move_notation: 'e5', player: :stockfish)
      move3 = double('Move', move_number: 3, move_notation: 'Nf3', player: :agent)

      validator_with_history = instance_double('MoveValidator')
      allow(validator_with_history).to receive(:current_fen).and_return('rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2')
      allow(validator_with_history).to receive(:legal_moves).and_return(['Nc6', 'd6', 'Nf6', 'Bc5'])
      allow(validator_with_history).to receive(:valid_move?).and_return(true)

      service = AgentMoveService.new(
        agent: agent,
        validator: validator_with_history,
        move_history: [move1, move2, move3],
        session: session
      )

      prompt = service.send(:build_prompt)
      expect(prompt).to include('1. e4 e5')
      expect(prompt).to include('2. Nf3')
    end
  end

  describe 'retry logic' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'when LLM suggests invalid move' do
      it 'retries up to 3 times' do
        # Mock validator to reject first move, accept second
        allow(validator).to receive(:valid_move?).with('Ke2').and_return(false)
        allow(validator).to receive(:valid_move?).with('e4').and_return(true)

        # Mock parse to return different moves
        call_count = 0
        allow(service).to receive(:parse_move_from_response) do
          call_count += 1
          call_count == 1 ? 'Ke2' : 'e4'
        end

        # Mock LLM to return responses
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_return(
          { content: 'MOVE: Ke2', usage: { total_tokens: 50 } },
          { content: 'MOVE: e4', usage: { total_tokens: 50 } }
        )

        result = service.generate_move
        expect(result[:move]).to eq('e4')
        expect(service).to have_received(:parse_move_from_response).twice
      end

      it 'raises error after 3 failed attempts' do
        # Mock validator to always reject
        allow(validator).to receive(:valid_move?).and_return(false)

        # Mock parse to always return invalid move
        allow(service).to receive(:parse_move_from_response).and_return('Ke2')

        # Mock LLM to return responses
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_return(
          { content: 'MOVE: Ke2', usage: { total_tokens: 50 } }
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::InvalidMoveError, /failed to produce valid move after 3 attempts/i)
      end
    end

    context 'when response has no parseable move' do
      it 'retries with more explicit prompt' do
        call_count = 0
        allow_any_instance_of(AnthropicClient).to receive(:complete) do
          call_count += 1
          if call_count == 1
            { content: "I think e4 is good", usage: { total_tokens: 50 } }  # No MOVE: marker
          else
            { content: "MOVE: e4", usage: { total_tokens: 50 } }             # Valid response
          end
        end

        result = service.generate_move
        expect(result[:move]).to eq('e4')
      end

      it 'raises error after 3 attempts with no parseable move' do
        # Mock parse to always return nil
        allow(service).to receive(:parse_move_from_response).and_return(nil)

        # Mock LLM to return responses
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_return(
          { content: 'I think e4 is good', usage: { total_tokens: 50 } }
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::InvalidMoveError, /failed after 3 attempts/i)
      end
    end
  end

  describe 'error handling' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'when LLM API fails' do
      it 'raises error with helpful message' do
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_raise(
          Faraday::Error.new('Connection failed')
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::LlmApiError, /Failed to get response from LLM/)
      end
    end

    context 'when LLM API times out' do
      it 'raises timeout error' do
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_raise(
          Faraday::TimeoutError
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::LlmApiError, /timeout/)
      end
    end

    context 'when session has no LLM config' do
      let(:empty_session) { {} }

      it 'raises configuration error' do
        expect {
          AgentMoveService.new(
            agent: agent,
            validator: validator,
            move_history: [],
            session: empty_session
          ).generate_move
        }.to raise_error(AgentMoveService::ConfigurationError, /LLM not configured/)
      end
    end
  end

  describe '#parse_move_from_response' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    it 'extracts move from "MOVE: e4" format' do
      response = "I will play e4 to control the center. MOVE: e4"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('e4')
    end

    it 'extracts move from different case' do
      response = "move: Nf3"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('Nf3')
    end

    it 'handles response with explanation after move' do
      response = "MOVE: d4\nThis controls the center and opens lines for my pieces."
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('d4')
    end

    it 'returns nil for response without move marker' do
      response = "I think e4 is the best move here."
      move = service.send(:parse_move_from_response, response)
      expect(move).to be_nil
    end

    it 'extracts first move if multiple present' do
      response = "MOVE: e4 or maybe MOVE: d4"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('e4')
    end
  end
end
