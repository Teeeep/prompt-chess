# Phase 2b: API Configuration (Session-Based, Anthropic) - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable users to configure Anthropic API credentials in session storage, test connections, and query/clear configuration via GraphQL.

**Architecture:** Session-based storage using Rails encrypted cookies, service layer for configuration management and API client, GraphQL mutations/queries for frontend interaction, VCR cassettes for API testing.

**Tech Stack:** Rails 8, GraphQL, Faraday (HTTP client), VCR/WebMock (API mocking), RSpec

---

## Prerequisites

Before starting implementation, verify:
- [ ] Phase 2a completed (GraphQL foundation)
- [ ] Working in feature branch: `feature/phase-2b-api-configuration`
- [ ] All Phase 2a tests passing

---

## Task 1: Add Dependencies

**Files:**
- Modify: `Gemfile`

**Step 1: Add Faraday gems to Gemfile**

Add after existing gem declarations:

```ruby
# HTTP client for Anthropic API
gem 'faraday', '~> 2.7'
gem 'faraday-retry', '~> 2.2'
```

**Step 2: Install dependencies**

Run: `bundle install`
Expected: Successfully installs faraday ~> 2.7.x and faraday-retry ~> 2.2.x

**Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "build: add faraday gems for API client

Add faraday and faraday-retry for making HTTP requests to Anthropic API.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: LlmConfigService (TDD)

**Files:**
- Create: `spec/services/llm_config_service_spec.rb`
- Create: `app/services/llm_config_service.rb`

**Step 1: Write the failing test**

Create `spec/services/llm_config_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe LlmConfigService do
  let(:session) { {} }
  let(:api_key) { 'sk-ant-api03-test1234567890abcdef' }
  let(:model) { 'claude-3-5-sonnet-20241022' }

  describe '.store' do
    it 'stores configuration in session' do
      LlmConfigService.store(
        session,
        provider: 'anthropic',
        api_key: api_key,
        model: model
      )

      expect(session[:llm_config]).to be_present
      expect(session[:llm_config][:provider]).to eq('anthropic')
      expect(session[:llm_config][:api_key]).to eq(api_key)
      expect(session[:llm_config][:model]).to eq(model)
    end

    it 'includes configured_at timestamp' do
      freeze_time do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )

        expect(session[:llm_config][:configured_at]).to eq(Time.current)
      end
    end
  end

  describe '.current' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )
      end

      it 'returns current configuration' do
        config = LlmConfigService.current(session)

        expect(config[:provider]).to eq('anthropic')
        expect(config[:api_key]).to eq(api_key)
        expect(config[:model]).to eq(model)
        expect(config[:configured_at]).to be_present
      end
    end

    context 'when not configured' do
      it 'returns nil' do
        expect(LlmConfigService.current(session)).to be_nil
      end
    end
  end

  describe '.masked_key' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: 'sk-ant-api03-test1234',
          model: model
        )
      end

      it 'returns last 4 characters of API key' do
        expect(LlmConfigService.masked_key(session)).to eq('...1234')
      end
    end

    context 'when not configured' do
      it 'returns nil' do
        expect(LlmConfigService.masked_key(session)).to be_nil
      end
    end
  end

  describe '.clear' do
    before do
      LlmConfigService.store(
        session,
        provider: 'anthropic',
        api_key: api_key,
        model: model
      )
    end

    it 'removes configuration from session' do
      LlmConfigService.clear(session)

      expect(session[:llm_config]).to be_nil
    end
  end

  describe '.configured?' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )
      end

      it 'returns true' do
        expect(LlmConfigService.configured?(session)).to be true
      end
    end

    context 'when not configured' do
      it 'returns false' do
        expect(LlmConfigService.configured?(session)).to be false
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/llm_config_service_spec.rb`
Expected: FAIL - "uninitialized constant LlmConfigService"

**Step 3: Write minimal implementation**

Create `app/services/llm_config_service.rb`:

```ruby
class LlmConfigService
  # Store LLM configuration in Rails session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @param provider [String] LLM provider name (e.g., 'anthropic')
  # @param api_key [String] API key for the provider
  # @param model [String] Model identifier (e.g., 'claude-3-5-sonnet-20241022')
  def self.store(session, provider:, api_key:, model:)
    session[:llm_config] = {
      provider: provider,
      api_key: api_key,
      model: model,
      configured_at: Time.current
    }
  end

  # Retrieve current LLM configuration from session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [Hash, nil] Configuration hash or nil if not configured
  def self.current(session)
    session[:llm_config]
  end

  # Get masked API key showing only last 4 characters
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [String, nil] Masked key (e.g., "...Ab3d") or nil if not configured
  def self.masked_key(session)
    return nil unless current(session)

    key = current(session)[:api_key]
    "...#{key[-4..]}"
  end

  # Clear LLM configuration from session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  def self.clear(session)
    session.delete(:llm_config)
  end

  # Check if LLM is configured in session
  #
  # @param session [ActionDispatch::Request::Session] Rails session object
  # @return [Boolean] true if configured, false otherwise
  def self.configured?(session)
    current(session).present?
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/llm_config_service_spec.rb`
Expected: All tests pass (7 examples, 0 failures)

**Step 5: Commit**

```bash
git add spec/services/llm_config_service_spec.rb app/services/llm_config_service.rb
git commit -m "feat(llm): add LlmConfigService for session-based storage

Implement service to store/retrieve LLM configuration in Rails encrypted
session cookies. Supports storing provider, API key, and model selection.
Includes API key masking for secure display.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: AnthropicClient (TDD with VCR)

**Files:**
- Create: `spec/services/anthropic_client_spec.rb`
- Create: `app/services/anthropic_client.rb`
- Create: `spec/vcr_cassettes/anthropic_test_connection_success.yml` (via VCR)
- Create: `spec/vcr_cassettes/anthropic_test_connection_invalid_key.yml` (via VCR)

**Step 1: Write the failing test**

Create `spec/services/anthropic_client_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe AnthropicClient do
  let(:api_key) { 'sk-ant-api03-valid-test-key' }
  let(:model) { 'claude-3-5-sonnet-20241022' }
  let(:client) { described_class.new(api_key: api_key, model: model) }

  describe '#test_connection' do
    context 'with valid API key', :vcr do
      it 'returns success with message' do
        result = client.test_connection

        expect(result[:success]).to be true
        expect(result[:message]).to include('Connected successfully')
      end
    end

    context 'with invalid API key', :vcr do
      let(:api_key) { 'sk-ant-api03-invalid-key' }

      it 'returns failure with authentication error' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid API key')
      end
    end

    context 'with permission denied', :vcr do
      let(:api_key) { 'sk-ant-api03-no-opus-access' }
      let(:model) { 'claude-3-opus-20240229' }

      it 'returns failure with permission error' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Permission denied')
      end
    end

    context 'with network error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'returns failure with network error message' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Network error')
      end
    end
  end

  describe '#complete' do
    it 'raises NotImplementedError with Phase 4 message' do
      expect {
        client.complete(prompt: 'test prompt')
      }.to raise_error(NotImplementedError, /Phase 4/)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/anthropic_client_spec.rb`
Expected: FAIL - "uninitialized constant AnthropicClient"

**Step 3: Write minimal implementation**

Create `app/services/anthropic_client.rb`:

```ruby
require 'faraday'

class AnthropicClient
  BASE_URL = 'https://api.anthropic.com/v1'
  API_VERSION = '2023-06-01'

  # Initialize Anthropic API client
  #
  # @param api_key [String] Anthropic API key (starts with 'sk-ant-')
  # @param model [String] Claude model identifier
  def initialize(api_key:, model:)
    @api_key = api_key
    @model = model
  end

  # Test API connection by making minimal API call
  #
  # @return [Hash] Result with :success (Boolean) and :message (String)
  def test_connection
    response = connection.post('/messages') do |req|
      req.body = {
        model: @model,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'Hi' }]
      }
    end

    if response.success?
      { success: true, message: 'Connected successfully to Anthropic API' }
    else
      parse_error(response)
    end
  rescue Faraday::ConnectionFailed => e
    { success: false, message: "Network error: #{e.message}" }
  rescue Faraday::Error => e
    { success: false, message: "Network error: #{e.message}" }
  end

  # Make completion request to Anthropic API
  # (To be implemented in Phase 4 - Agent Move Generation)
  #
  # @param prompt [String] User prompt
  # @param max_tokens [Integer] Maximum tokens to generate
  # @param temperature [Float] Sampling temperature
  # @raise [NotImplementedError] Always raises - implemented in Phase 4
  def complete(prompt:, max_tokens: 1000, temperature: 0.7)
    raise NotImplementedError,
      "Complete method will be implemented in Phase 4 (Agent Move Generation)"
  end

  private

  # Create Faraday connection with Anthropic headers
  #
  # @return [Faraday::Connection]
  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.headers['x-api-key'] = @api_key
      f.headers['anthropic-version'] = API_VERSION
      f.headers['content-type'] = 'application/json'
      f.adapter Faraday.default_adapter
    end
  end

  # Parse error response from Anthropic API
  #
  # @param response [Faraday::Response] HTTP response
  # @return [Hash] Result with :success false and :message
  def parse_error(response)
    error = response.body&.dig('error') || {}

    case error['type']
    when 'authentication_error'
      { success: false, message: 'Invalid API key. Please check your Anthropic API key.' }
    when 'permission_error'
      { success: false, message: 'Permission denied. Check your API key has access to this model.' }
    when 'rate_limit_error'
      { success: false, message: 'Rate limit exceeded. Please try again later.' }
    else
      message = error['message'] || 'Unknown API error'
      { success: false, message: "API error: #{message}" }
    end
  end
end
```

**Step 4: Record VCR cassettes (requires real API key)**

**IMPORTANT:** This step requires a real Anthropic API key. Two options:

**Option A: Use real API key temporarily to record cassettes**
```bash
# Set real API key (get from https://console.anthropic.com/)
export ANTHROPIC_API_KEY=sk-ant-api03-your-real-key

# Run tests to record cassettes
bundle exec rspec spec/services/anthropic_client_spec.rb

# Unset API key
unset ANTHROPIC_API_KEY
```

**Option B: Create mock cassettes manually (if no API key available)**

See design document section "VCR Configuration" for cassette structure. Mock cassettes should be created in `spec/vcr_cassettes/` directory.

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/services/anthropic_client_spec.rb`
Expected: All tests pass (5 examples, 0 failures)

Note: Tests should pass whether using real recorded cassettes or mock cassettes.

**Step 6: Commit**

```bash
git add spec/services/anthropic_client_spec.rb app/services/anthropic_client.rb spec/vcr_cassettes/
git commit -m "feat(llm): add AnthropicClient for API communication

Implement HTTP client for Anthropic Messages API with:
- Connection testing with minimal API call
- Error parsing (auth, permission, rate limit)
- VCR cassettes for offline testing
- Placeholder for complete() method (Phase 4)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: GraphQL Type Definitions

**Files:**
- Create: `app/graphql/types/llm_config_type.rb`
- Create: `app/graphql/types/inputs/configure_anthropic_api_input.rb`
- Create: `app/graphql/types/payloads/configure_anthropic_api_payload.rb`
- Create: `app/graphql/types/payloads/test_api_connection_payload.rb`
- Create: `app/graphql/types/payloads/clear_api_config_payload.rb`

**Step 1: Create LlmConfigType**

Create `app/graphql/types/llm_config_type.rb`:

```ruby
module Types
  class LlmConfigType < Types::BaseObject
    description "Current LLM API configuration for the session"

    field :provider, String, null: false,
      description: "LLM provider name (e.g., 'anthropic')"

    field :model, String, null: false,
      description: "Selected model (e.g., 'claude-3-5-sonnet-20241022')"

    field :api_key_last_four, String, null: false,
      description: "Last 4 characters of API key for verification"

    field :configured_at, GraphQL::Types::ISO8601DateTime, null: false,
      description: "When this configuration was set"
  end
end
```

**Step 2: Create input type**

Create `app/graphql/types/inputs/configure_anthropic_api_input.rb`:

```ruby
module Types
  module Inputs
    class ConfigureAnthropicApiInput < Types::BaseInputObject
      description "Input for configuring Anthropic API"

      argument :api_key, String, required: true,
        description: "Anthropic API key (starts with 'sk-ant-')"

      argument :model, String, required: true,
        description: "Claude model to use"
    end
  end
end
```

**Step 3: Create payload types**

Create `app/graphql/types/payloads/configure_anthropic_api_payload.rb`:

```ruby
module Types
  module Payloads
    class ConfigureAnthropicApiPayload < Types::BaseObject
      description "Payload returned from configureAnthropicApi mutation"

      field :config, Types::LlmConfigType, null: true,
        description: "The configured LLM settings (null if errors occurred)"

      field :errors, [String], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
```

Create `app/graphql/types/payloads/test_api_connection_payload.rb`:

```ruby
module Types
  module Payloads
    class TestApiConnectionPayload < Types::BaseObject
      description "Payload returned from testApiConnection mutation"

      field :success, Boolean, null: false,
        description: "Whether the connection test succeeded"

      field :message, String, null: false,
        description: "Human-readable result message"

      field :errors, [String], null: false,
        description: "Error messages (empty array if successful)"
    end
  end
end
```

Create `app/graphql/types/payloads/clear_api_config_payload.rb`:

```ruby
module Types
  module Payloads
    class ClearApiConfigPayload < Types::BaseObject
      description "Payload returned from clearApiConfig mutation"

      field :success, Boolean, null: false,
        description: "Whether the configuration was cleared"
    end
  end
end
```

**Step 4: Verify types load without errors**

Run: `bundle exec rails runner "puts PromptChessSchema.to_definition"`
Expected: GraphQL schema prints without errors (new types may not appear yet since mutations aren't registered)

**Step 5: Commit**

```bash
git add app/graphql/types/llm_config_type.rb \
        app/graphql/types/inputs/configure_anthropic_api_input.rb \
        app/graphql/types/payloads/
git commit -m "feat(graphql): add LLM config types and payloads

Add GraphQL types for LLM configuration API:
- LlmConfigType: represents current session config
- ConfigureAnthropicApiInput: mutation input
- Payload types: for configure, test, and clear operations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: ConfigureAnthropicApi Mutation (TDD)

**Files:**
- Create: `spec/requests/graphql/mutations/configure_anthropic_api_spec.rb`
- Create: `app/graphql/mutations/configure_anthropic_api.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/mutations/configure_anthropic_api_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Mutations::ConfigureAnthropicApi', type: :request do
  let(:query) do
    <<~GQL
      mutation ConfigureAnthropicApi($apiKey: String!, $model: String!) {
        configureAnthropicApi(apiKey: $apiKey, model: $model) {
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/mutations/configure_anthropic_api_spec.rb`
Expected: FAIL - mutation field not found or not registered

**Step 3: Write minimal implementation**

Create `app/graphql/mutations/configure_anthropic_api.rb`:

```ruby
module Mutations
  class ConfigureAnthropicApi < BaseMutation
    description "Configure Anthropic API credentials and model selection"

    argument :api_key, String, required: true,
      description: "Anthropic API key (starts with 'sk-ant-')"
    argument :model, String, required: true,
      description: "Claude model to use"

    field :config, Types::LlmConfigType, null: true,
      description: "The configured LLM settings (null if errors occurred)"
    field :errors, [String], null: false,
      description: "Validation errors (empty array if successful)"

    ALLOWED_MODELS = [
      'claude-3-5-sonnet-20241022',
      'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229'
    ].freeze

    def resolve(api_key:, model:)
      errors = []

      # Validate API key format
      unless api_key.start_with?('sk-ant-')
        errors << "API key must start with 'sk-ant-'"
      end

      # Validate model
      unless ALLOWED_MODELS.include?(model)
        errors << "Model must be one of: #{ALLOWED_MODELS.join(', ')}"
      end

      return { config: nil, errors: errors } if errors.any?

      # Store in session
      LlmConfigService.store(
        context[:session],
        provider: 'anthropic',
        api_key: api_key,
        model: model
      )

      # Return config with masked key
      config = LlmConfigService.current(context[:session])
      {
        config: {
          provider: config[:provider],
          model: config[:model],
          api_key_last_four: LlmConfigService.masked_key(context[:session]),
          configured_at: config[:configured_at]
        },
        errors: []
      }
    end
  end
end
```

**Step 4: Register mutation in MutationType**

Modify `app/graphql/types/mutation_type.rb`:

Add this field:
```ruby
field :configure_anthropic_api, mutation: Mutations::ConfigureAnthropicApi
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/mutations/configure_anthropic_api_spec.rb`
Expected: All tests pass (6 examples, 0 failures)

**Step 6: Commit**

```bash
git add spec/requests/graphql/mutations/configure_anthropic_api_spec.rb \
        app/graphql/mutations/configure_anthropic_api.rb \
        app/graphql/types/mutation_type.rb
git commit -m "feat(graphql): add configureAnthropicApi mutation

Implement mutation to store Anthropic API credentials in session:
- Validates API key format (must start with 'sk-ant-')
- Validates model against allowed list
- Stores in encrypted session via LlmConfigService
- Returns config with masked API key

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: TestApiConnection Mutation (TDD)

**Files:**
- Create: `spec/requests/graphql/mutations/test_api_connection_spec.rb`
- Create: `app/graphql/mutations/test_api_connection.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/mutations/test_api_connection_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Mutations::TestApiConnection', type: :request do
  let(:query) do
    <<~GQL
      mutation {
        testApiConnection {
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
    before do
      # Configure session with valid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "sk-ant-api03-valid-test-key",
              model: "claude-3-5-sonnet-20241022"
            ) {
              config { provider }
              errors
            }
          }
        GQL
      }
    end

    it 'returns success true' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['success']).to be true
    end

    it 'returns success message' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['message']).to include('Connected successfully')
    end

    it 'returns empty errors array' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['errors']).to eq([])
    end
  end

  context 'when configured with invalid key', :vcr do
    before do
      # Configure session with invalid API key
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "sk-ant-api03-invalid-key",
              model: "claude-3-5-sonnet-20241022"
            ) {
              config { provider }
              errors
            }
          }
        GQL
      }
    end

    it 'returns success false' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['success']).to be false
    end

    it 'returns authentication error message' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['message']).to include('Invalid API key')
    end

    it 'includes error in errors array' do
      result = execute_mutation

      data = result.dig('data', 'testApiConnection')
      expect(data['errors'].size).to eq(1)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/mutations/test_api_connection_spec.rb`
Expected: FAIL - mutation field not found or not registered

**Step 3: Write minimal implementation**

Create `app/graphql/mutations/test_api_connection.rb`:

```ruby
module Mutations
  class TestApiConnection < BaseMutation
    description "Test the configured API connection"

    field :success, Boolean, null: false,
      description: "Whether the connection test succeeded"
    field :message, String, null: false,
      description: "Human-readable result message"
    field :errors, [String], null: false,
      description: "Error messages (empty array if successful)"

    def resolve
      config = LlmConfigService.current(context[:session])

      unless config
        return {
          success: false,
          message: 'No API configuration found',
          errors: ['Please configure your API credentials first']
        }
      end

      # Test connection based on provider
      result = case config[:provider]
      when 'anthropic'
        client = AnthropicClient.new(
          api_key: config[:api_key],
          model: config[:model]
        )
        client.test_connection
      else
        { success: false, message: "Unknown provider: #{config[:provider]}" }
      end

      {
        success: result[:success],
        message: result[:message],
        errors: result[:success] ? [] : [result[:message]]
      }
    end
  end
end
```

**Step 4: Register mutation in MutationType**

Modify `app/graphql/types/mutation_type.rb`:

Add this field:
```ruby
field :test_api_connection, mutation: Mutations::TestApiConnection
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/mutations/test_api_connection_spec.rb`
Expected: All tests pass (7 examples, 0 failures)

Note: Requires VCR cassettes from Task 3.

**Step 6: Commit**

```bash
git add spec/requests/graphql/mutations/test_api_connection_spec.rb \
        app/graphql/mutations/test_api_connection.rb \
        app/graphql/types/mutation_type.rb
git commit -m "feat(graphql): add testApiConnection mutation

Implement mutation to test API connection:
- Checks if configuration exists in session
- Routes to appropriate client based on provider
- Returns success/failure with human-readable message
- Uses VCR cassettes for testing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: ClearApiConfig Mutation (TDD)

**Files:**
- Create: `spec/requests/graphql/mutations/clear_api_config_spec.rb`
- Create: `app/graphql/mutations/clear_api_config.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/mutations/clear_api_config_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Mutations::ClearApiConfig', type: :request do
  let(:query) do
    <<~GQL
      mutation {
        clearApiConfig {
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
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            ) {
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
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/mutations/clear_api_config_spec.rb`
Expected: FAIL - mutation field not found or not registered

**Step 3: Write minimal implementation**

Create `app/graphql/mutations/clear_api_config.rb`:

```ruby
module Mutations
  class ClearApiConfig < BaseMutation
    description "Clear the current API configuration from session"

    field :success, Boolean, null: false,
      description: "Whether the configuration was cleared (always true)"

    def resolve
      LlmConfigService.clear(context[:session])
      { success: true }
    end
  end
end
```

**Step 4: Register mutation in MutationType**

Modify `app/graphql/types/mutation_type.rb`:

Add this field:
```ruby
field :clear_api_config, mutation: Mutations::ClearApiConfig
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/mutations/clear_api_config_spec.rb`
Expected: All tests pass (3 examples, 0 failures)

**Step 6: Commit**

```bash
git add spec/requests/graphql/mutations/clear_api_config_spec.rb \
        app/graphql/mutations/clear_api_config.rb \
        app/graphql/types/mutation_type.rb
git commit -m "feat(graphql): add clearApiConfig mutation

Implement mutation to clear API configuration from session.
Returns success true (idempotent operation).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: CurrentLlmConfig Query (TDD)

**Files:**
- Create: `spec/requests/graphql/queries/current_llm_config_spec.rb`
- Modify: `app/graphql/types/query_type.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/queries/current_llm_config_spec.rb`:

```ruby
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
    before do
      # Configure session
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            ) {
              config { provider }
              errors
            }
          }
        GQL
      }
    end

    it 'returns current configuration' do
      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['provider']).to eq('anthropic')
      expect(config['model']).to eq('claude-3-5-sonnet-20241022')
    end

    it 'masks API key showing only last 4 characters' do
      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['apiKeyLastFour']).to eq('...1234')
    end

    it 'includes configured_at timestamp' do
      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config['configuredAt']).to be_present
      expect(Time.parse(config['configuredAt'])).to be_within(5.seconds).of(Time.current)
    end

    it 'includes all required fields' do
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
    before do
      # Configure then clear
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "sk-ant-api03-test1234",
              model: "claude-3-5-sonnet-20241022"
            ) {
              config { provider }
              errors
            }
          }
        GQL
      }

      post '/graphql', params: {
        query: 'mutation { clearApiConfig { success } }'
      }
    end

    it 'returns null' do
      result = execute_query

      config = result.dig('data', 'currentLlmConfig')
      expect(config).to be_nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/queries/current_llm_config_spec.rb`
Expected: FAIL - query field not found

**Step 3: Add query to QueryType**

Modify `app/graphql/types/query_type.rb`:

Add this field:
```ruby
field :current_llm_config, Types::LlmConfigType, null: true,
  description: "Returns current LLM configuration for this session"

def current_llm_config
  config = LlmConfigService.current(context[:session])
  return nil unless config

  {
    provider: config[:provider],
    model: config[:model],
    api_key_last_four: LlmConfigService.masked_key(context[:session]),
    configured_at: config[:configured_at]
  }
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/queries/current_llm_config_spec.rb`
Expected: All tests pass (7 examples, 0 failures)

**Step 5: Commit**

```bash
git add spec/requests/graphql/queries/current_llm_config_spec.rb \
        app/graphql/types/query_type.rb
git commit -m "feat(graphql): add currentLlmConfig query

Implement query to retrieve current session's LLM configuration:
- Returns null when not configured
- Masks API key (shows only last 4 chars)
- Includes provider, model, and timestamp

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: Security Configuration

**Files:**
- Modify: `config/initializers/filter_parameter_logging.rb`
- Verify: `config/initializers/session_store.rb`

**Step 1: Add API key filtering to parameter logging**

Modify `config/initializers/filter_parameter_logging.rb`:

Ensure these parameters are filtered:
```ruby
Rails.application.config.filter_parameters += [
  :api_key,
  :apiKey,
  :password,
  :secret,
  :token,
  :authentication_token,
  :secret_key
]
```

**Step 2: Verify session store configuration**

Check `config/initializers/session_store.rb` (should already exist from Rails setup):

```ruby
Rails.application.config.session_store :cookie_store,
  key: '_prompt_chess_session',
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,                  # Not accessible via JavaScript
  same_site: :lax                  # CSRF protection
```

If file doesn't exist, create it with above content.

**Step 3: Test parameter filtering**

Create a simple test to verify filtering works:

```bash
bundle exec rails runner "
  Rails.logger.info 'Testing with api_key: sk-ant-test123'
  puts 'Check logs - API key should be filtered'
"
```

Check `log/development.log` - should see `api_key: [FILTERED]`

**Step 4: Commit**

```bash
git add config/initializers/filter_parameter_logging.rb config/initializers/session_store.rb
git commit -m "feat(security): configure API key filtering and session security

Add parameter filtering for API keys and sensitive data.
Ensure session cookies are secure (HTTPS only in production).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 10: Integration Testing & Coverage

**Files:**
- Create: `spec/requests/graphql/llm_config_integration_spec.rb`

**Step 1: Write integration test covering full workflow**

Create `spec/requests/graphql/llm_config_integration_spec.rb`:

```ruby
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
            configureAnthropicApi(
              apiKey: "#{valid_api_key}",
              model: "#{valid_model}"
            ) {
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
      expect(config['provider']).to eq('anthropic')
      expect(config['errors']).to eq([])

      # Step 3: Test connection
      post '/graphql', params: {
        query: <<~GQL
          mutation {
            testApiConnection {
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
        query: 'mutation { clearApiConfig { success } }'
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

  describe 'error handling workflow' do
    it 'validates before storing, fails test with invalid key' do
      # Step 1: Try invalid API key format
      post '/graphql', params: {
        query: <<~GQL,
          mutation {
            configureAnthropicApi(
              apiKey: "invalid-key",
              model: "#{valid_model}"
            ) {
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
            configureAnthropicApi(
              apiKey: "#{valid_api_key}",
              model: "claude-unknown"
            ) {
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
            configureAnthropicApi(
              apiKey: "sk-ant-api03-invalid-key",
              model: "#{valid_model}"
            ) {
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
            testApiConnection {
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
```

**Step 2: Run integration tests**

Run: `bundle exec rspec spec/requests/graphql/llm_config_integration_spec.rb`
Expected: All tests pass (2 examples, 0 failures)

**Step 3: Check test coverage**

Run: `bundle exec rspec --format documentation`
Expected: All Phase 2b tests pass

Run coverage check (if SimpleCov configured):
```bash
COVERAGE=true bundle exec rspec
open coverage/index.html
```

Expected: ≥90% coverage for:
- `app/services/llm_config_service.rb`
- `app/services/anthropic_client.rb`
- `app/graphql/mutations/configure_anthropic_api.rb`
- `app/graphql/mutations/test_api_connection.rb`
- `app/graphql/mutations/clear_api_config.rb`

**Step 4: Commit**

```bash
git add spec/requests/graphql/llm_config_integration_spec.rb
git commit -m "test(integration): add LLM config workflow tests

Add integration tests covering complete workflows:
- Configure → Test → Query → Clear (happy path)
- Error handling for invalid inputs and failed connections

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 11: Documentation & Verification

**Files:**
- Create: `docs/api/llm-configuration.md` (optional)
- Run verification checklist

**Step 1: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass (Phase 1, 2a, 2b)

**Step 2: Verify GraphQL schema**

Run: `bundle exec rails runner "puts PromptChessSchema.to_definition" > schema.graphql`
Check that schema includes:
- `currentLlmConfig` query
- `configureAnthropicApi` mutation
- `testApiConnection` mutation
- `clearApiConfig` mutation
- `LlmConfigType` type

**Step 3: Manual GraphQL testing (optional)**

Start server: `bundle exec rails server`

Test via GraphiQL (http://localhost:3000/graphiql):

```graphql
# Configure
mutation {
  configureAnthropicApi(
    apiKey: "sk-ant-api03-your-key"
    model: "claude-3-5-sonnet-20241022"
  ) {
    config {
      provider
      model
      apiKeyLastFour
      configuredAt
    }
    errors
  }
}

# Test
mutation {
  testApiConnection {
    success
    message
    errors
  }
}

# Query
query {
  currentLlmConfig {
    provider
    model
    apiKeyLastFour
    configuredAt
  }
}

# Clear
mutation {
  clearApiConfig {
    success
  }
}
```

**Step 4: Verification Checklist**

Review Phase 2b completion criteria:

### Functionality
- [ ] Can configure Anthropic API via GraphQL ✓
- [ ] Can test connection and get success/failure ✓
- [ ] Can query current config (with masked key) ✓
- [ ] Can clear config ✓
- [ ] Invalid inputs return proper errors ✓

### Security
- [ ] API key only stored in encrypted session ✓
- [ ] Full API key never returned in GraphQL ✓
- [ ] API key filtered from logs ✓
- [ ] HTTPS enforced in production ✓

### Testing
- [ ] All tests pass ✓
- [ ] Coverage ≥ 90% ✓
- [ ] VCR cassettes recorded and working ✓
- [ ] Can run tests without real API key ✓

### Code Quality
- [ ] All commits use conventional format ✓
- [ ] TDD followed (RED-GREEN-REFACTOR) ✓
- [ ] No commented-out code ✓
- [ ] Services follow Rails conventions ✓

**Step 5: Final commit (if any docs added)**

```bash
git add docs/api/llm-configuration.md  # if created
git commit -m "docs: add LLM configuration API documentation

Document GraphQL API for LLM configuration including:
- Available mutations and queries
- Example usage
- Error handling

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Completion

**Phase 2b is complete when:**
1. All tests pass (unit, integration, request specs)
2. Test coverage ≥ 90% for new code
3. All verification checklist items checked
4. Code committed with conventional commit messages
5. Feature branch ready for review/merge

**Next Steps:**
- Review PR with @superpowers:requesting-code-review
- Merge to main after approval
- Continue to Phase 3 (Game Creation & Management)

---

**Plan Status:** Ready for Execution
**Estimated Time:** 3-4 hours (assuming VCR cassettes can be recorded)
**Dependencies:** Phase 2a (GraphQL) must be complete
