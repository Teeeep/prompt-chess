require 'rails_helper'

RSpec.describe 'Mutations::ClearApiConfig', type: :request do
  let(:query) do
    <<~GQL
      mutation {
        clearApiConfig(input: {}) {
          success
        }
      }
    GQL
  end

  def execute_mutation
    post '/graphql', params: { query: query }
    JSON.parse(response.body)
  end

  context 'when configuration exists' do
    before do
      # Configure session first
      post '/graphql', params: {
        query: <<~GQL
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-haiku-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }
    end

    it 'returns success true' do
      result = execute_mutation

      data = result.dig('data', 'clearApiConfig')
      expect(data['success']).to be true
    end

    it 'clears configuration from session' do
      execute_mutation

      # Verify via currentLlmConfig query (next task)
      # For now, test service directly
      expect(session[:llm_config]).to be_nil
    end
  end

  context 'when no configuration exists' do
    it 'returns success true (idempotent)' do
      result = execute_mutation

      data = result.dig('data', 'clearApiConfig')
      expect(data['success']).to be true
    end
  end
end
