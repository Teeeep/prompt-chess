require 'rails_helper'

RSpec.describe 'CreateMatch Integration', type: :request do
  let(:agent) { create(:agent) }

  let(:mutation) do
    <<~GQL
      mutation($agentId: ID!, $stockfishLevel: Int!) {
        createMatch(input: {agentId: $agentId, stockfishLevel: $stockfishLevel}) {
          match {
            id
            status
            stockfishLevel
            agent {
              id
              name
            }
          }
          errors
        }
      }
    GQL
  end

  def default_session_config
    {
      llm_config: {
        provider: 'anthropic',
        api_key: ENV['ANTHROPIC_API_KEY'] || 'sk-ant-api03-test1234567890abcdef',
        model: 'claude-3-5-haiku-20241022'
      }
    }
  end

  def configure_session_for_graphql(session_config = default_session_config)
    # Mock the GraphQL controller's session to return our config
    # This simulates what the configureAnthropicApi mutation does
    allow_any_instance_of(GraphqlController).to receive(:session).and_return(session_config)
  end

  def create_match(agent_id:, stockfish_level:, configure: true)
    # Configure session before making the request
    if configure
      configure_session_for_graphql
    else
      configure_session_for_graphql({})
    end

    post '/graphql', params: {
      query: mutation,
      variables: { agentId: agent_id, stockfishLevel: stockfish_level }.to_json
    }

    JSON.parse(response.body)
  end

  describe 'full flow from GraphQL to match execution' do
    it 'creates a match and enqueues the job' do
      result = create_match(agent_id: agent.id, stockfish_level: 1)

      expect(result['data']['createMatch']['errors']).to be_empty

      match_data = result['data']['createMatch']['match']
      expect(match_data['status']).to eq('PENDING')
      expect(match_data['stockfishLevel']).to eq(1)
      expect(match_data['agent']['id']).to eq(agent.id.to_s)

      # Verify job was enqueued
      expect(MatchExecutionJob).to have_been_enqueued
    end

    it 'executes the match when job runs' do
      result = create_match(agent_id: agent.id, stockfish_level: 1)

      # Mock agent moves to return valid chess moves in sequence
      call_count = 0
      valid_moves = ['e4', 'Nf3']

      allow_any_instance_of(AgentMoveService).to receive(:generate_move) do
        move = valid_moves[call_count % valid_moves.length]
        call_count += 1
        {
          move: move,
          prompt: "test prompt for #{move}",
          response: "test response: MOVE: #{move}",
          tokens: 100,
          time_ms: 500
        }
      end

      # Stub game to end quickly (after 2 agent moves + 2 stockfish moves = 4 total moves)
      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(false, false, false, false, true)

      perform_enqueued_jobs

      match_id = result['data']['createMatch']['match']['id']
      match = Match.find(match_id)

      # Verify match completed
      expect(match.status_completed?).to be true
      expect(match.moves.count).to be > 0
      expect(match.total_moves).to eq(match.moves.count)

      # Verify moves alternate between players
      moves = match.moves.order(:move_number)
      expect(moves.first.player).to eq('agent')
      expect(moves.second&.player).to eq('stockfish') if moves.count > 1

      # Verify agent moves have LLM data
      agent_move = moves.where(player: :agent).first
      expect(agent_move.llm_prompt).to be_present
      expect(agent_move.llm_response).to be_present
      expect(agent_move.tokens_used).to be > 0

      # Verify stockfish moves don't have LLM data
      stockfish_move = moves.where(player: :stockfish).first
      expect(stockfish_move&.llm_prompt).to be_nil if stockfish_move
    end

    context 'with invalid input' do
      it 'returns validation errors for non-existent agent' do
        result = create_match(agent_id: 999, stockfish_level: 1)

        errors = result['data']['createMatch']['errors']
        expect(errors).to include('Agent not found')
        expect(result['data']['createMatch']['match']).to be_nil
      end

      it 'returns validation errors for invalid stockfish level' do
        result = create_match(agent_id: agent.id, stockfish_level: 99)

        errors = result['data']['createMatch']['errors']
        expect(errors).to include('Stockfish level must be between 1 and 8')
        expect(result['data']['createMatch']['match']).to be_nil
      end

      it 'does not enqueue job when validation fails' do
        create_match(agent_id: 999, stockfish_level: 1)

        expect(MatchExecutionJob).not_to have_been_enqueued
      end
    end
  end

  describe 'without API configuration' do
    it 'returns error about missing API credentials' do
      # Don't configure API
      result = create_match(agent_id: agent.id, stockfish_level: 1, configure: false)

      errors = result['data']['createMatch']['errors']
      expect(errors).to include('Please configure your API credentials first')
      expect(result['data']['createMatch']['match']).to be_nil
    end

    it 'does not enqueue job without API configuration' do
      create_match(agent_id: agent.id, stockfish_level: 1, configure: false)

      expect(MatchExecutionJob).not_to have_been_enqueued
    end
  end

  describe 'querying match status during execution' do
    let(:query) do
      <<~GQL
        query($id: ID!) {
          match(id: $id) {
            id
            status
            totalMoves
            moves {
              moveNumber
              player
              moveNotation
            }
          }
        }
      GQL
    end

    it 'returns match with moves after execution' do
      result = create_match(agent_id: agent.id, stockfish_level: 1)
      match_id = result['data']['createMatch']['match']['id']

      # Mock agent moves to return valid chess moves
      call_count = 0
      valid_moves = ['e4', 'Nf3']

      allow_any_instance_of(AgentMoveService).to receive(:generate_move) do
        move = valid_moves[call_count % valid_moves.length]
        call_count += 1
        {
          move: move,
          prompt: "test prompt for #{move}",
          response: "test response: MOVE: #{move}",
          tokens: 100,
          time_ms: 500
        }
      end

      # Stub game to end quickly (after 2 agent moves + 2 stockfish moves = 4 total moves)
      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(false, false, false, false, true)

      perform_enqueued_jobs

      # Query the match
      post '/graphql', params: {
        query: query,
        variables: { id: match_id }.to_json
      }

      expect(response).to have_http_status(:success)

      query_result = JSON.parse(response.body)
      match_data = query_result['data']['match']

      expect(match_data['status']).to eq('COMPLETED')
      expect(match_data['totalMoves']).to be > 0
      expect(match_data['moves']).to be_an(Array)
      expect(match_data['moves'].length).to eq(match_data['totalMoves'])
    end

    it 'returns pending status before execution' do
      result = create_match(agent_id: agent.id, stockfish_level: 1)
      match_id = result['data']['createMatch']['match']['id']

      # Query immediately without running job
      post '/graphql', params: {
        query: query,
        variables: { id: match_id }.to_json
      }

      query_result = JSON.parse(response.body)
      match_data = query_result['data']['match']

      expect(match_data['status']).to eq('PENDING')
      expect(match_data['totalMoves']).to eq(0)
      expect(match_data['moves']).to be_empty
    end
  end
end
