require 'rails_helper'

RSpec.describe 'Matches GraphQL API', type: :request do
  let(:agent) { create(:agent) }

  describe 'Query: match' do
    let(:match) { create(:match, agent: agent) }
    let!(:move1) { create(:move, :agent_move, match: match, move_number: 1) }
    let!(:move2) { create(:move, :stockfish_move, match: match, move_number: 2) }

    let(:query) do
      <<~GQL
        query($id: ID!) {
          match(id: $id) {
            id
            agent { id }
            stockfishLevel
            status
            totalMoves
            moves {
              id
              moveNumber
              player
              moveNotation
              llmPrompt
              llmResponse
              tokensUsed
            }
          }
        }
      GQL
    end

    it 'returns match with moves in order' do
      post '/graphql', params: { query: query, variables: { id: match.id } }
      result = JSON.parse(response.body)

      match_data = result.dig('data', 'match')
      expect(match_data['id']).to eq(match.id.to_s)
      expect(match_data['moves'].length).to eq(2)

      # Verify move order
      expect(match_data['moves'][0]['moveNumber']).to eq(1)
      expect(match_data['moves'][1]['moveNumber']).to eq(2)

      # Verify agent move has LLM data
      agent_move = match_data['moves'][0]
      expect(agent_move['player']).to eq('AGENT')
      expect(agent_move['llmPrompt']).to be_present
      expect(agent_move['llmResponse']).to be_present
      expect(agent_move['tokensUsed']).to be > 0

      # Verify stockfish move has no LLM data
      stockfish_move = match_data['moves'][1]
      expect(stockfish_move['player']).to eq('STOCKFISH')
      expect(stockfish_move['llmPrompt']).to be_nil
      expect(stockfish_move['llmResponse']).to be_nil
      expect(stockfish_move['tokensUsed']).to be_nil
    end

    it 'returns null for non-existent match' do
      post '/graphql', params: { query: query, variables: { id: 99999 } }
      result = JSON.parse(response.body)

      expect(result.dig('data', 'match')).to be_nil
    end
  end

  describe 'Query: matches' do
    let(:agent2) { create(:agent) }
    let!(:pending_match) { create(:match, agent: agent, status: :pending) }
    let!(:completed_match) { create(:match, :completed, agent: agent) }
    let!(:other_agent_match) { create(:match, agent: agent2) }

    let(:query) do
      <<~GQL
        query($agentId: ID, $status: MatchStatusEnum) {
          matches(agentId: $agentId, status: $status) {
            id
            agent { id }
            status
          }
        }
      GQL
    end

    it 'returns all matches without filters' do
      post '/graphql', params: { query: query }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      # Should include at least our 3 test matches
      expect(matches.length).to be >= 3
      # Verify our test matches are present
      match_ids = matches.map { |m| m['id'].to_i }
      expect(match_ids).to include(pending_match.id, completed_match.id, other_agent_match.id)
    end

    it 'filters by agent_id' do
      post '/graphql', params: { query: query, variables: { agentId: agent.id } }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(2)
      expect(matches.map { |m| m['agent']['id'] }.uniq).to eq([ agent.id.to_s ])
    end

    it 'filters by status' do
      post '/graphql', params: { query: query, variables: { status: 'COMPLETED' } }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(1)
      expect(matches[0]['status']).to eq('COMPLETED')
    end

    it 'filters by agent_id and status' do
      post '/graphql', params: {
        query: query,
        variables: { agentId: agent.id, status: 'PENDING' }
      }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(1)
      expect(matches[0]['id']).to eq(pending_match.id.to_s)
    end

    it 'orders matches by created_at descending' do
      post '/graphql', params: { query: query }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      ids = matches.map { |m| m['id'].to_i }

      # Newest match should be first
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
