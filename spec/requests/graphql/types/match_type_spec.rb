require 'rails_helper'

RSpec.describe Types::MatchType, type: :request do
  let(:match) { create(:match, :completed, :agent_won) }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        match(id: $id) {
          id
          agent {
            id
            name
          }
          stockfishLevel
          status
          winner
          resultReason
          startedAt
          completedAt
          totalMoves
          openingName
          totalTokensUsed
          totalCostCents
          averageMoveTimeMs
          finalBoardState
          errorMessage
          createdAt
          updatedAt
        }
      }
    GQL
  end

  def execute_query(id:)
    post '/graphql', params: { query: query, variables: { id: id } }
    JSON.parse(response.body)
  end

  it 'returns all match fields' do
    result = execute_query(id: match.id)

    match_data = result.dig('data', 'match')
    expect(match_data['id']).to eq(match.id.to_s)
    expect(match_data['stockfishLevel']).to eq(5)
    expect(match_data['status']).to eq('COMPLETED')
    expect(match_data['winner']).to eq('AGENT')
    expect(match_data['resultReason']).to eq('checkmate')
    expect(match_data['totalMoves']).to eq(42)
    expect(match_data['openingName']).to eq('Sicilian Defense')
    expect(match_data['totalTokensUsed']).to eq(3500)
    expect(match_data['totalCostCents']).to eq(5)
    expect(match_data['averageMoveTimeMs']).to eq(850)
    expect(match_data['finalBoardState']).to be_present
  end

  it 'includes agent association' do
    result = execute_query(id: match.id)

    agent_data = result.dig('data', 'match', 'agent')
    expect(agent_data['id']).to eq(match.agent.id.to_s)
    expect(agent_data['name']).to eq(match.agent.name)
  end
end
