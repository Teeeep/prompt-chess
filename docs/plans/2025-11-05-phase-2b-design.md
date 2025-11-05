# Phase 2b: API Configuration (Session-Based, Anthropic) - Design Document

**Date**: 2025-11-05
**Phase**: 2b (Split from Phase 2)
**Status**: Design Complete, Ready for Planning
**Branch**: `feature/phase-2b-api-configuration`

---

## Overview

### Goal
Enable users to configure Anthropic API credentials and model selection for their session. All agents in that session will use this configuration to make LLM API calls.

### Philosophy
- Session-based storage (no user accounts needed for MVP)
- Anthropic-first implementation, but architected for easy provider extension
- Global session config: one API key + model choice per session
- Security: encrypted session storage, masked API keys in responses
- Testable: VCR cassettes for API call mocking

### Success Criteria
- Users can store Anthropic API key + model choice in session
- Can test API connection to verify key works
- Can query current configuration (with masked API key)
- Can clear configuration
- All tests pass with VCR cassettes
- No sensitive data exposed in logs or GraphQL responses

---

## Design Decisions

### Session-Based Storage (No Database)

**Decision**: Store API configuration in Rails encrypted session cookies, not in database.

**Rationale**:
- MVP explicitly excludes user accounts
- Configuration only needed during active session
- Rails sessions are encrypted by default (secure)
- Simplifies architecture (no database table, no cleanup jobs)
- Fast access (no database queries)

**Trade-offs**:
- User must re-enter API key each session
- Can't persist across devices
- Session expires when browser closes

**Future Migration Path**: When we add user accounts (Phase 2e), migrate to database-backed storage with user_id foreign key.

### Global Session Config (Not Per-Agent)

**Decision**: One API configuration per session applies to all agents.

**Rationale**:
- Simpler UX: configure once, use everywhere
- Matches "I have one Anthropic subscription" use case
- Reduces complexity in agent creation flow
- Adequate for MVP experimentation

**Trade-offs**:
- Can't compare different models in same match (e.g., haiku vs sonnet)
- All agents use same API key

**Future Enhancement**: Add per-agent model override in Agent model (optional `preferred_model` field).

### Anthropic-First, Extensible Architecture

**Decision**: Implement Anthropic fully now, but structure code to easily add OpenAI/others later.

**Design**:
```ruby
# Session structure supports any provider
session[:llm_config] = {
  provider: 'anthropic',  # or 'openai', 'ollama', etc.
  api_key: '...',
  model: 'claude-3-5-sonnet-20241022',
  configured_at: Time.current
}
```

**Extension Path**:
1. Add `configureOpenaiApi` mutation
2. Add `OpenaiClient` service
3. Add provider-specific model lists
4. Router in `LlmConfigService` based on provider

### Model Selection

**Decision**: Support Claude 3.5 family with clear cost/performance options.

**Supported Models**:

1. **claude-3-5-sonnet-20241022** (Default)
   - Best balance of intelligence and speed
   - Pricing: $3/M input tokens, $15/M output tokens
   - Use case: Most chess gameplay

2. **claude-3-5-haiku-20241022**
   - Fastest and cheapest
   - Pricing: $1/M input tokens, $5/M output tokens
   - Use case: Rapid games, budget testing

3. **claude-3-opus-20240229**
   - Most powerful (if user has access)
   - Pricing: $15/M input tokens, $75/M output tokens
   - Use case: Complex positional analysis

**Rationale**: Three options provide meaningful cost/performance trade-offs without overwhelming user.

### Security Approach

**API Key Protection**:
1. **Storage**: Encrypted in Rails session cookie (uses `secret_key_base`)
2. **Transport**: HTTPS only (enforced in production)
3. **Display**: Only show last 4 characters (e.g., "...Ab3d")
4. **Logging**: Filter API keys from logs (Rails.application.config.filter_parameters)
5. **GraphQL**: Never return full key in queries

**Example**:
```ruby
# Stored in session (encrypted)
session[:llm_config][:api_key] = "sk-ant-api03-1234567890abcdef..."

# Returned in GraphQL
{ apiKeyLastFour: "cdef" }
```

---

## Architecture

### Session Storage Structure

```ruby
session[:llm_config] = {
  provider: 'anthropic',                    # String
  api_key: 'sk-ant-api03-...',             # String (encrypted in session)
  model: 'claude-3-5-sonnet-20241022',     # String
  configured_at: Time.current               # DateTime
}
```

**Access Pattern**:
```ruby
# Store config
LlmConfigService.store(session, provider: 'anthropic', api_key: key, model: model)

# Retrieve config
config = LlmConfigService.current(session)
# => { provider: 'anthropic', api_key: '...', model: '...', configured_at: ... }

# Masked key for display
masked = LlmConfigService.masked_key(session)
# => "...Ab3d"

# Clear config
LlmConfigService.clear(session)
```

### Service Layer

#### LlmConfigService

**Responsibility**: Manage LLM configuration in Rails session.

**Location**: `app/services/llm_config_service.rb`

**Public Methods**:
```ruby
class LlmConfigService
  # Store configuration in session
  def self.store(session, provider:, api_key:, model:)
    session[:llm_config] = {
      provider: provider,
      api_key: api_key,
      model: model,
      configured_at: Time.current
    }
  end

  # Retrieve current configuration
  def self.current(session)
    session[:llm_config]
  end

  # Get masked API key (last 4 chars only)
  def self.masked_key(session)
    return nil unless current(session)
    key = current(session)[:api_key]
    "...#{key[-4..]}"
  end

  # Clear configuration
  def self.clear(session)
    session.delete(:llm_config)
  end

  # Check if configured
  def self.configured?(session)
    current(session).present?
  end
end
```

#### AnthropicClient

**Responsibility**: Make API calls to Anthropic (Messages API).

**Location**: `app/services/anthropic_client.rb`

**Public Methods**:
```ruby
class AnthropicClient
  BASE_URL = 'https://api.anthropic.com/v1'
  API_VERSION = '2023-06-01'

  def initialize(api_key:, model:)
    @api_key = api_key
    @model = model
  end

  # Test API connection (returns { success: bool, message: string })
  def test_connection
    response = connection.post('/messages') do |req|
      req.body = {
        model: @model,
        max_tokens: 10,
        messages: [{ role: 'user', content: 'Hi' }]
      }.to_json
    end

    if response.success?
      { success: true, message: 'Connected successfully to Anthropic API' }
    else
      parse_error(response)
    end
  rescue Faraday::Error => e
    { success: false, message: "Network error: #{e.message}" }
  end

  # Make completion request (implementation in Phase 4)
  def complete(prompt:, max_tokens: 1000, temperature: 0.7)
    # To be implemented when agent move generation is built
    raise NotImplementedError, "Complete method will be implemented in Phase 4"
  end

  private

  def connection
    Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.headers['x-api-key'] = @api_key
      f.headers['anthropic-version'] = API_VERSION
      f.headers['content-type'] = 'application/json'
    end
  end

  def parse_error(response)
    error = response.body['error']
    case error['type']
    when 'authentication_error'
      { success: false, message: 'Invalid API key. Please check your Anthropic API key.' }
    when 'permission_error'
      { success: false, message: 'Permission denied. Check your API key has access to this model.' }
    when 'rate_limit_error'
      { success: false, message: 'Rate limit exceeded. Please try again later.' }
    else
      { success: false, message: "API error: #{error['message']}" }
    end
  end
end
```

**Dependencies**:
- `faraday` gem for HTTP requests
- `faraday-json` middleware for JSON handling

---

## GraphQL API

### Type Definitions

#### LlmConfigType

**File**: `app/graphql/types/llm_config_type.rb`

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

### Input Types

#### ConfigureAnthropicApiInput

**File**: `app/graphql/types/inputs/configure_anthropic_api_input.rb`

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

### Payload Types

#### ConfigureAnthropicApiPayload

**File**: `app/graphql/types/payloads/configure_anthropic_api_payload.rb`

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

#### TestApiConnectionPayload

**File**: `app/graphql/types/payloads/test_api_connection_payload.rb`

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

#### ClearApiConfigPayload

**File**: `app/graphql/types/payloads/clear_api_config_payload.rb`

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

### Queries

#### currentLlmConfig

**Add to**: `app/graphql/types/query_type.rb`

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

### Mutations

#### ConfigureAnthropicApi

**File**: `app/graphql/mutations/configure_anthropic_api.rb`

```ruby
module Mutations
  class ConfigureAnthropicApi < BaseMutation
    description "Configure Anthropic API credentials and model selection"

    argument :api_key, String, required: true
    argument :model, String, required: true

    field :config, Types::LlmConfigType, null: true
    field :errors, [String], null: false

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

      # Return config (with masked key)
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

#### TestApiConnection

**File**: `app/graphql/mutations/test_api_connection.rb`

```ruby
module Mutations
  class TestApiConnection < BaseMutation
    description "Test the configured API connection"

    field :success, Boolean, null: false
    field :message, String, null: false
    field :errors, [String], null: false

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

#### ClearApiConfig

**File**: `app/graphql/mutations/clear_api_config.rb`

```ruby
module Mutations
  class ClearApiConfig < BaseMutation
    description "Clear the current API configuration from session"

    field :success, Boolean, null: false

    def resolve
      LlmConfigService.clear(context[:session])
      { success: true }
    end
  end
end
```

**Register Mutations** in `app/graphql/types/mutation_type.rb`:
```ruby
field :configure_anthropic_api, mutation: Mutations::ConfigureAnthropicApi
field :test_api_connection, mutation: Mutations::TestApiConnection
field :clear_api_config, mutation: Mutations::ClearApiConfig
```

---

## Testing Strategy

### Test Coverage Requirements
- **Minimum**: 90% overall coverage
- **Target**: 100% coverage on new services and mutations

### Test Organization

```
spec/
├── services/
│   ├── llm_config_service_spec.rb       # Session storage tests
│   └── anthropic_client_spec.rb         # API client tests
├── requests/
│   └── graphql/
│       └── llm_config_spec.rb           # GraphQL API tests
└── vcr_cassettes/
    ├── anthropic_test_connection_success.yml
    └── anthropic_test_connection_invalid_key.yml
```

### Service Tests

#### LlmConfigService Tests

**File**: `spec/services/llm_config_service_spec.rb`

```ruby
RSpec.describe LlmConfigService do
  let(:session) { {} }

  describe '.store' do
    it 'stores configuration in session'
    it 'includes configured_at timestamp'
  end

  describe '.current' do
    it 'returns current configuration'
    it 'returns nil when not configured'
  end

  describe '.masked_key' do
    it 'returns last 4 characters of API key'
    it 'returns nil when not configured'
  end

  describe '.clear' do
    it 'removes configuration from session'
  end

  describe '.configured?' do
    it 'returns true when configured'
    it 'returns false when not configured'
  end
end
```

#### AnthropicClient Tests

**File**: `spec/services/anthropic_client_spec.rb`

```ruby
RSpec.describe AnthropicClient do
  let(:api_key) { 'sk-ant-test-key' }
  let(:model) { 'claude-3-5-sonnet-20241022' }
  let(:client) { described_class.new(api_key: api_key, model: model) }

  describe '#test_connection', :vcr do
    context 'with valid API key' do
      it 'returns success' do
        result = client.test_connection
        expect(result[:success]).to be true
        expect(result[:message]).to include('Connected successfully')
      end
    end

    context 'with invalid API key' do
      let(:api_key) { 'sk-ant-invalid' }

      it 'returns failure with error message' do
        result = client.test_connection
        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid API key')
      end
    end

    context 'with rate limit error' do
      it 'returns rate limit message'
    end

    context 'with network error' do
      it 'returns network error message'
    end
  end

  describe '#complete' do
    it 'raises NotImplementedError' do
      expect {
        client.complete(prompt: 'test')
      }.to raise_error(NotImplementedError, /Phase 4/)
    end
  end
end
```

### GraphQL Tests

**File**: `spec/requests/graphql/llm_config_spec.rb`

```ruby
RSpec.describe 'LLM Configuration GraphQL API', type: :request do
  describe 'Query: currentLlmConfig' do
    context 'when configured' do
      before do
        # Set up session with config
      end

      it 'returns current configuration'
      it 'masks API key'
      it 'includes all fields'
    end

    context 'when not configured' do
      it 'returns null'
    end
  end

  describe 'Mutation: configureAnthropicApi' do
    context 'with valid input' do
      it 'stores configuration in session'
      it 'returns config with masked key'
      it 'returns empty errors array'
    end

    context 'with invalid API key format' do
      it 'returns validation error'
      it 'does not store configuration'
    end

    context 'with invalid model' do
      it 'returns validation error'
    end
  end

  describe 'Mutation: testApiConnection', :vcr do
    context 'when configured with valid key' do
      it 'returns success true'
      it 'returns success message'
    end

    context 'when configured with invalid key' do
      it 'returns success false'
      it 'returns error message'
    end

    context 'when not configured' do
      it 'returns error about missing configuration'
    end
  end

  describe 'Mutation: clearApiConfig' do
    it 'clears configuration from session'
    it 'returns success true'
  end
end
```

### VCR Configuration

**Update**: `spec/support/vcr.rb`

```ruby
VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Filter sensitive data
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') do |interaction|
    interaction.request.headers['X-Api-Key']&.first
  end

  c.allow_http_connections_when_no_cassette = false
end
```

**Recording Cassettes**:
```bash
# Set real API key temporarily
export ANTHROPIC_API_KEY=sk-ant-your-real-key

# Record cassettes
bundle exec rspec spec/services/anthropic_client_spec.rb

# Unset API key
unset ANTHROPIC_API_KEY
```

---

## Error Handling

### Validation Errors

**API Key Format**:
- Message: "API key must start with 'sk-ant-'"
- When: Key doesn't match expected format
- Response: 400-style GraphQL error (in errors array)

**Model Name**:
- Message: "Model must be one of: claude-3-5-sonnet-20241022, claude-3-5-haiku-20241022, claude-3-opus-20240229"
- When: Unknown model specified
- Response: 400-style GraphQL error

### API Errors

**Authentication Error**:
- Message: "Invalid API key. Please check your Anthropic API key."
- When: Anthropic returns 401
- Handled in: AnthropicClient#parse_error

**Permission Error**:
- Message: "Permission denied. Check your API key has access to this model."
- When: Anthropic returns 403
- Common cause: User doesn't have access to claude-3-opus

**Rate Limit**:
- Message: "Rate limit exceeded. Please try again later."
- When: Anthropic returns 429
- User action: Wait and retry

**Network Error**:
- Message: "Unable to connect to Anthropic API. Please check your connection."
- When: Faraday raises connection error
- User action: Check network, retry

### Session Errors

**No Configuration**:
- Behavior: `currentLlmConfig` query returns `null`
- Message: Not an error, just indicates unconfigured state
- User action: Run `configureAnthropicApi` mutation

---

## Security Considerations

### API Key Protection

1. **Storage**:
   - Encrypted in Rails session cookie
   - Uses `secret_key_base` for encryption
   - Never stored in database

2. **Transport**:
   - HTTPS enforced in production
   - Session cookie marked `secure: true`
   - Session cookie marked `httponly: true`

3. **Display**:
   - GraphQL only returns last 4 characters
   - Full key never in GraphQL responses
   - Full key never logged

4. **Logging**:
   ```ruby
   # config/initializers/filter_parameter_logging.rb
   Rails.application.config.filter_parameters += [
     :api_key,
     :password,
     :secret,
     :token
   ]
   ```

5. **GraphQL Context**:
   ```ruby
   # app/controllers/graphql_controller.rb
   context = {
     session: session,
     # Never pass full config to resolvers
   }
   ```

### Session Security

**Configuration**:
```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: '_prompt_chess_session',
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,                  # Not accessible via JavaScript
  same_site: :lax                  # CSRF protection
```

**Session Timeout**:
- Default Rails behavior: expires when browser closes
- No automatic server-side timeout (stateless sessions)
- User can manually clear via `clearApiConfig` mutation

### XSS Prevention

**GraphQL Responses**:
- All GraphQL responses are JSON (not HTML)
- Rails automatically escapes when rendering in views
- API key masked before returning to client

---

## Dependencies

### New Gems

Add to `Gemfile`:

```ruby
# HTTP client for Anthropic API
gem 'faraday', '~> 2.7'
gem 'faraday-retry', '~> 2.2'

# JSON handling
gem 'faraday-json', '~> 1.0'
```

Install:
```bash
bundle install
```

### Existing Dependencies

- `graphql` - Already installed (Phase 2a)
- `vcr` - Already installed (Phase 1)
- `webmock` - Already installed (Phase 1)
- `rspec-rails` - Already installed (Phase 1)

---

## Implementation Order (TDD)

### Task 1: LlmConfigService
1. Write service tests (RED)
2. Implement service (GREEN)
3. Commit

### Task 2: AnthropicClient
1. Write client tests with VCR (RED)
2. Implement client (GREEN)
3. Record VCR cassettes
4. Commit

### Task 3: GraphQL Types
1. Create LlmConfigType
2. Create input types
3. Create payload types
4. Commit

### Task 4: Configure Mutation
1. Write mutation tests (RED)
2. Implement ConfigureAnthropicApi (GREEN)
3. Commit

### Task 5: Test Connection Mutation
1. Write mutation tests with VCR (RED)
2. Implement TestApiConnection (GREEN)
3. Commit

### Task 6: Clear Mutation
1. Write mutation tests (RED)
2. Implement ClearApiConfig (GREEN)
3. Commit

### Task 7: Query Implementation
1. Write query tests (RED)
2. Implement currentLlmConfig query (GREEN)
3. Commit

### Task 8: Integration Testing
1. Test full flow (configure → test → query → clear)
2. Verify VCR cassettes work
3. Check coverage (should be 90%+)

---

## Verification Checklist

Before marking Phase 2b complete:

### Functionality
- [ ] Can configure Anthropic API via GraphQL
- [ ] Can test connection and get success/failure
- [ ] Can query current config (with masked key)
- [ ] Can clear config
- [ ] Invalid inputs return proper errors

### Security
- [ ] API key only stored in encrypted session
- [ ] Full API key never returned in GraphQL
- [ ] API key filtered from logs
- [ ] HTTPS enforced in production

### Testing
- [ ] All tests pass (bundle exec rspec)
- [ ] Coverage ≥ 90%
- [ ] VCR cassettes recorded and working
- [ ] Can run tests without real API key

### Code Quality
- [ ] All commits use conventional format
- [ ] TDD followed (RED-GREEN-REFACTOR)
- [ ] No commented-out code
- [ ] Services follow Rails conventions

---

## Future Extensions

### When Adding OpenAI (Phase 2b+)

1. Add `configureOpenaiApi` mutation
2. Create `OpenaiClient` service
3. Update `testApiConnection` to route by provider
4. Add OpenAI models to allowed list

### When Adding User Accounts (Phase 2e)

1. Create `api_configurations` table
2. Migrate from session storage to database
3. Add `user_id` foreign key
4. Keep session as fallback for anonymous users

### When Adding Per-Agent Models (Future)

1. Add `preferred_model` column to `agents` table (nullable)
2. Fallback to session config if null
3. Update agent form UI to show model selector

---

## Example Usage

### GraphQL Examples

**Configure API**:
```graphql
mutation {
  configureAnthropicApi(
    apiKey: "sk-ant-api03-..."
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
```

**Test Connection**:
```graphql
mutation {
  testApiConnection {
    success
    message
    errors
  }
}
```

**Query Current Config**:
```graphql
query {
  currentLlmConfig {
    provider
    model
    apiKeyLastFour
    configuredAt
  }
}
```

**Clear Config**:
```graphql
mutation {
  clearApiConfig {
    success
  }
}
```

---

## Design Status

**Status**: ✅ Complete and Validated
**Next Step**: Create implementation plan using `superpowers:writing-plans`

---

**Design completed**: 2025-11-05
**Ready for**: Implementation (Phase 2b)
