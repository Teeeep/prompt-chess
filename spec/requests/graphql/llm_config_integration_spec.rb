require 'rails_helper'

RSpec.describe 'LLM Configuration Integration', type: :request do
  let(:valid_api_key) { 'sk-ant-api03-valid-test-key' }
  let(:valid_model) { 'claude-3-5-sonnet-20241022' }

  describe 'full workflow: configure → test → query → clear', :vcr do
    it 'completes successfully' do
      # Step 1: Verify no configuration initially
      post '/graphql', params: {
        query: 'query { currentLlmConfig { provider } }'
      }
      result = JSON.parse(response.body)
      expect(result.dig('data', 'currentLlmConfig')).to be_nil

      # Step 2: Configure API
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "#{valid_api_key}",
              model: "#{valid_model}"
            }) {
              config {
                provider
                model
                apiKeyLastFour
              }
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      config = result.dig('data', 'configureAnthropicApi', 'config')
      errors = result.dig('data', 'configureAnthropicApi', 'errors')
      expect(config['provider']).to eq('anthropic')
      expect(errors).to eq([])

      # Step 3: Test connection
      post '/graphql', params: {
        query: <<~GQL
          mutation {
            testApiConnection(input: {}) {
              success
              message
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      test_result = result.dig('data', 'testApiConnection')
      expect(test_result['success']).to be true
      expect(test_result['message']).to include('Connected successfully')

      # Step 4: Query current config
      post '/graphql', params: {
        query: <<~GQL
          query {
            currentLlmConfig {
              provider
              model
              apiKeyLastFour
              configuredAt
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      config = result.dig('data', 'currentLlmConfig')
      expect(config['provider']).to eq('anthropic')
      expect(config['model']).to eq(valid_model)

      # Step 5: Clear config
      post '/graphql', params: {
        query: 'mutation { clearApiConfig(input: {}) { success } }'
      }
      result = JSON.parse(response.body)
      expect(result.dig('data', 'clearApiConfig', 'success')).to be true

      # Step 6: Verify config is cleared
      post '/graphql', params: {
        query: 'query { currentLlmConfig { provider } }'
      }
      result = JSON.parse(response.body)
      expect(result.dig('data', 'currentLlmConfig')).to be_nil
    end
  end

  describe 'error handling workflow', :vcr do
    it 'validates before storing, fails test with invalid key' do
      # Step 1: Try invalid API key format
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "invalid-key",
              model: "#{valid_model}"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      errors = result.dig('data', 'configureAnthropicApi', 'errors')
      expect(errors).to include(/sk-ant-/)

      # Step 2: Try invalid model
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "#{valid_api_key}",
              model: "claude-unknown"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      errors = result.dig('data', 'configureAnthropicApi', 'errors')
      expect(errors).to include(/Model must be one of/)

      # Step 3: Configure with valid format but invalid key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-invalid-key",
              model: "#{valid_model}"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      expect(result.dig('data', 'configureAnthropicApi', 'errors')).to eq([])

      # Step 4: Test connection should fail
      post '/graphql', params: {
        query: <<~GQL
          mutation {
            testApiConnection(input: {}) {
              success
              message
              errors
            }
          }
        GQL
      }
      result = JSON.parse(response.body)
      test_result = result.dig('data', 'testApiConnection')
      expect(test_result['success']).to be false
      expect(test_result['message']).to include('Invalid API key')
    end
  end
end
