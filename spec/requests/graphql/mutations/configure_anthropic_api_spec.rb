require 'rails_helper'

RSpec.describe 'Mutations::ConfigureAnthropicApi', type: :request do
  let(:query) do
    <<~GQL
      mutation ConfigureAnthropicApi($apiKey: String!, $model: String!) {
        configureAnthropicApi(input: {apiKey: $apiKey, model: $model}) {
          config {
            provider
            model
            apiKeyLastFour
            configuredAt
          }
          errors
        }
      }
    GQL
  end

  let(:valid_api_key) { 'sk-ant-api03-test1234567890abcdef' }
  let(:valid_model) { 'claude-3-5-sonnet-20241022' }

  def execute_mutation(api_key:, model:)
    post '/graphql', params: {
      query: query,
      variables: { apiKey: api_key, model: model }
    }
    JSON.parse(response.body)
  end

  context 'with valid input' do
    it 'stores configuration in session' do
      result = execute_mutation(api_key: valid_api_key, model: valid_model)

      config = result.dig('data', 'configureAnthropicApi', 'config')
      expect(config['provider']).to eq('anthropic')
      expect(config['model']).to eq(valid_model)
      expect(config['apiKeyLastFour']).to eq('...cdef')
      expect(config['configuredAt']).to be_present
    end

    it 'returns empty errors array' do
      result = execute_mutation(api_key: valid_api_key, model: valid_model)

      errors = result.dig('data', 'configureAnthropicApi', 'errors')
      expect(errors).to eq([])
    end

    it 'persists configuration to session' do
      execute_mutation(api_key: valid_api_key, model: valid_model)

      # Verify session was updated (check via query in next task)
      expect(session[:llm_config]).to be_present
    end
  end

  context 'with invalid API key format' do
    it 'returns validation error for wrong prefix' do
      result = execute_mutation(api_key: 'invalid-key', model: valid_model)

      config = result.dig('data', 'configureAnthropicApi', 'config')
      errors = result.dig('data', 'configureAnthropicApi', 'errors')

      expect(config).to be_nil
      expect(errors).to include("API key must start with 'sk-ant-'")
    end
  end

  context 'with invalid model' do
    it 'returns validation error for unknown model' do
      result = execute_mutation(api_key: valid_api_key, model: 'claude-unknown')

      config = result.dig('data', 'configureAnthropicApi', 'config')
      errors = result.dig('data', 'configureAnthropicApi', 'errors')

      expect(config).to be_nil
      expect(errors).to include(/Model must be one of/)
    end
  end

  context 'with multiple validation errors' do
    it 'returns all errors' do
      result = execute_mutation(api_key: 'bad-key', model: 'bad-model')

      errors = result.dig('data', 'configureAnthropicApi', 'errors')
      expect(errors.size).to eq(2)
    end
  end
end
