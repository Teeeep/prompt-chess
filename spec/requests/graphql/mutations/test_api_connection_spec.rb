require 'rails_helper'

RSpec.describe 'Mutations::TestApiConnection', type: :request do
  let(:query) do
    <<~GQL
      mutation {
        testApiConnection(input: {}) {
          success
          message
          errors
        }
      }
    GQL
  end

  def execute_mutation
    post '/graphql', params: { query: query }
    JSON.parse(response.body)
  end

  context 'when not configured' do
    it 'returns error about missing configuration' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['success']).to be false
      expect(data['message']).to include('No API configuration found')
      expect(data['errors']).to include('Please configure your API credentials first')
    end
  end

  context 'when configured with valid key', :vcr do
    let(:test_api_key) { ENV['ANTHROPIC_API_KEY'] || 'sk-ant-api03-valid-test-key' }
    let(:test_model) { 'claude-3-5-haiku-20241022' }

    it 'returns success true' do
      # Configure session with valid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "#{test_api_key}",
              model: "#{test_model}"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['success']).to be true
    end

    it 'returns success message' do
      # Configure session with valid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "#{test_api_key}",
              model: "#{test_model}"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['message']).to include('Connected successfully')
    end

    it 'returns empty errors array' do
      # Configure session with valid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "#{test_api_key}",
              model: "#{test_model}"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['errors']).to eq([])
    end
  end

  context 'when configured with invalid key', :vcr do
    it 'returns success false' do
      # Configure session with invalid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-invalid-key",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['success']).to be false
    end

    it 'returns authentication error message' do
      # Configure session with invalid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-invalid-key",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['message']).to include('Invalid API key')
    end

    it 'includes error in errors array' do
      # Configure session with invalid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-invalid-key",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['errors'].size).to eq(1)
    end
  end
end
