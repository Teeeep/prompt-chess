require 'rails_helper'

RSpec.describe 'Mutations::CreateMatch', type: :request do
  let(:agent) { create(:agent) }
  let(:session_data) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  let(:mutation) do
    <<~GQL
      mutation($agentId: ID!, $stockfishLevel: Int!) {
        createMatch(agentId: $agentId, stockfishLevel: $stockfishLevel) {
          match {
            id
            agent { id }
            stockfishLevel
            status
          }
          errors
        }
      }
    GQL
  end

  def execute_mutation(agent_id:, stockfish_level:, configure_llm: false)
    # Set up session if requested
    if configure_llm
      post '/graphql', params: {
        query: <<~GQL
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234567890abcdef",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
            }
          }
        GQL
      }
    end

    # Now call createMatch
    post '/graphql', params: {
      query: mutation,
      variables: { agentId: agent_id, stockfishLevel: stockfish_level }
    }

    JSON.parse(response.body)
  end

  describe 'successful creation' do
    it 'creates a match' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 5, configure_llm: true)
      }.to change { Match.count }.by(1)

      result = JSON.parse(response.body)
      match_data = result.dig('data', 'createMatch', 'match')

      expect(match_data['agent']['id']).to eq(agent.id.to_s)
      expect(match_data['stockfishLevel']).to eq(5)
      expect(match_data['status']).to eq('PENDING')
    end

    it 'enqueues MatchExecutionJob' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 3, configure_llm: true)
      }.to have_enqueued_job(MatchExecutionJob)
    end

    it 'passes session to job' do
      execute_mutation(agent_id: agent.id, stockfish_level: 5, configure_llm: true)

      expect(MatchExecutionJob).to have_been_enqueued.with { |match_id, session|
        expect(match_id).to be_a(Integer)
        expect(session).to be_a(Hash)
      }
    end

    it 'returns no errors' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 5, configure_llm: true)
      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to be_empty
    end
  end

  describe 'validation errors' do
    it 'returns error for non-existent agent' do
      result = execute_mutation(agent_id: 99999, stockfish_level: 5, configure_llm: true)

      match_data = result.dig('data', 'createMatch', 'match')
      errors = result.dig('data', 'createMatch', 'errors')

      expect(match_data).to be_nil
      expect(errors).to include('Agent not found')
    end

    it 'returns error for invalid stockfish level (too low)' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 0, configure_llm: true)

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Stockfish level must be between 1 and 8')
    end

    it 'returns error for invalid stockfish level (too high)' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 9, configure_llm: true)

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Stockfish level must be between 1 and 8')
    end

    it 'returns error when LLM not configured' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 5, configure_llm: false)

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Please configure your API credentials first')
    end

    it 'does not create match when validation fails' do
      expect {
        execute_mutation(agent_id: 99999, stockfish_level: 5, configure_llm: true)
      }.not_to change { Match.count }
    end

    it 'does not enqueue job when validation fails' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 0, configure_llm: true)
      }.not_to have_enqueued_job(MatchExecutionJob)
    end
  end
end
