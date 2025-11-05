require 'rails_helper'

RSpec.describe 'Queries::CurrentLlmConfig', type: :request do
  let(:query) do
    <<~GQL
      query {
        currentLlmConfig {
          provider
          model
          apiKeyLastFour
          configuredAt
        }
      }
    GQL
  end

  def execute_query
    post '/graphql', params: { query: query }
    JSON.parse(response.body)
  end

  context 'when configured' do
    it 'returns current configuration' do
      # Configure session
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['provider']).to eq('anthropic')
      expect(config['model']).to eq('claude-3-5-sonnet-20241022')
    end

    it 'masks API key showing only last 4 characters' do
      # Configure session
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['apiKeyLastFour']).to eq('...1234')
    end

    it 'includes configured_at timestamp' do
      # Configure session
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['configuredAt']).to be_present
      expect(Time.parse(config['configuredAt'])).to be_within(5.seconds).of(Time.current)
    end

    it 'includes all required fields' do
      # Configure session
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config.keys).to match_array(%w[provider model apiKeyLastFour configuredAt])
    end
  end

  context 'when not configured' do
    it 'returns null' do
      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config).to be_nil
    end
  end

  context 'after clearing configuration' do
    it 'returns null' do
      # Configure then clear
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(input: {
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            }) {
              config { provider }
              errors
            }
          }
        GQL
      }

      post '/graphql', params: {
        query: 'mutation { clearApiConfig(input: {}) { success } }'
      }

      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config).to be_nil
    end
  end
end
