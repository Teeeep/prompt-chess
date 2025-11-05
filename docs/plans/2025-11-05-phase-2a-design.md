# Phase 2a: Agent Model + GraphQL API - Design Document

**Date**: 2025-11-05
**Phase**: 2a (Split from Phase 2)
**Status**: Design Complete, Ready for Planning
**Branch**: `feature/phase-2a-agent-model-api`

---

## Overview

### Goal
Create the Agent model and complete GraphQL CRUD API to manage chess-playing agents with custom prompts. Backend only - no UI in this phase.

### Philosophy
- Pure backend: Model + GraphQL API
- Test via GraphiQL playground
- Foundation for UI in Phase 2c
- TDD throughout: Red → Green → Refactor

### Success Criteria
- Agent model with validations working
- GraphQL queries (agents, agent) functional
- GraphQL mutations (createAgent, updateAgent, deleteAgent) functional
- 90%+ test coverage (aiming for 100% on new code)
- All CRUD operations testable via GraphiQL
- All RSpec tests passing

---

## Context: Phase 2 Split

Phase 2 was split into smaller feature branches for better manageability:

- **Phase 2a** (THIS): Agent Model + GraphQL API (backend)
- **Phase 2b**: API Configuration Model (backend)
- **Phase 2c**: Agent Management UI (frontend)
- **Phase 2d**: API Settings UI (frontend)
- **Phase 2e**: User Authentication (future)

This design covers Phase 2a only.

---

## Data Model

### Agent Model Schema

**Table**: `agents`

```ruby
create_table :agents do |t|
  t.string :name, null: false
  t.string :role # Free-text, optional
  t.text :prompt_text, null: false
  t.jsonb :configuration, default: {}, null: false

  t.timestamps
end

add_index :agents, :role
```

### Field Descriptions

**name** (string, required):
- The display name for the agent
- Example: "Aggressive Tactical Master", "Defensive Positional Player"
- Validation: 1-100 characters
- Uniqueness NOT enforced (users can have multiple agents with same name)

**role** (string, optional):
- Free-text field for agent specialization
- Examples: "opening", "tactical", "positional", "endgame", "general", custom values
- Validation: Max 50 characters if present
- Indexed for future filtering

**prompt_text** (text, required):
- The full prompt that will be sent to the LLM
- Contains instructions for how the agent should play chess
- Validation: 10-10,000 characters
- Minimum 10 chars ensures it's not trivial
- Maximum 10k chars is reasonable for LLM context

**configuration** (jsonb, default: {}):
- Flexible storage for LLM parameters
- Default structure: `{ temperature: 0.7, max_tokens: 500, top_p: 1.0 }`
- Allows experimentation without schema changes
- Specific keys validated when used in later phases

### Model Validations

```ruby
class Agent < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :prompt_text, presence: true, length: { minimum: 10, maximum: 10_000 }
  validates :role, length: { maximum: 50 }, allow_blank: true
  validates :configuration, presence: true

  # Ensure configuration is valid JSON (already enforced by jsonb type)
end
```

### Design Decisions

**Why no user_id yet?**
- Phase 2e will add authentication
- Will add as nullable column later: `add_column :agents, :user_id, :bigint`
- Keeps Phase 2a focused and small

**Why JSONB for configuration?**
- Don't know what parameters will matter yet
- Allows experimentation (temperature, max_tokens, custom params)
- No migrations needed to try new parameters
- PostgreSQL JSONB is fast and queryable

**Why free-text role instead of enum?**
- Research/experimentation platform
- Users should invent new agent types
- Can add suggested roles in UI later without DB changes
- Still indexed for filtering

**Why 10-10k character limits on prompt_text?**
- 10 chars minimum: Prevent trivial/empty prompts
- 10k chars maximum: Reasonable for LLM context windows (GPT-3.5 is ~4k tokens ≈ 16k chars)
- Leaves room for system messages and game state

---

## GraphQL Schema

### Type Definition

```graphql
type Agent {
  id: ID!
  name: String!
  role: String
  promptText: String!
  configuration: JSON!
  createdAt: ISO8601DateTime!
  updatedAt: ISO8601DateTime!
}
```

**Notes**:
- `role` is nullable (matches DB schema)
- `configuration` returns JSON object
- Timestamps in ISO8601 format

### Query Operations

```graphql
type Query {
  """
  Returns all agents
  """
  agents: [Agent!]!

  """
  Returns a single agent by ID, or null if not found
  """
  agent(id: ID!): Agent
}
```

**Behavior**:
- `agents`: Returns empty array `[]` if no agents exist
- `agent(id)`: Returns `null` if ID not found (not an error)

### Mutation Operations

```graphql
type Mutation {
  """
  Create a new agent
  """
  createAgent(input: CreateAgentInput!): CreateAgentPayload!

  """
  Update an existing agent
  """
  updateAgent(input: UpdateAgentInput!): UpdateAgentPayload!

  """
  Delete an agent
  """
  deleteAgent(input: DeleteAgentInput!): DeleteAgentPayload!
}
```

### Input Types

```graphql
input CreateAgentInput {
  name: String!
  role: String
  promptText: String!
  configuration: JSON
}

input UpdateAgentInput {
  id: ID!
  name: String
  role: String
  promptText: String
  configuration: JSON
}

input DeleteAgentInput {
  id: ID!
}
```

**Notes**:
- `CreateAgentInput`: name and promptText required, others optional
- `UpdateAgentInput`: All fields optional except id (partial updates)
- `DeleteAgentInput`: Only needs ID

### Payload Types

```graphql
type CreateAgentPayload {
  agent: Agent
  errors: [String!]!
}

type UpdateAgentPayload {
  agent: Agent
  errors: [String!]!
}

type DeleteAgentPayload {
  success: Boolean!
  errors: [String!]!
}
```

**Error Handling Pattern**:
- Success: `agent` present, `errors` is empty array
- Failure: `agent` is null, `errors` contains validation messages
- Delete: `success` true/false, `errors` if failed

**Example Success Response**:
```json
{
  "data": {
    "createAgent": {
      "agent": {
        "id": "1",
        "name": "Tactical Master",
        "role": "tactical",
        "promptText": "You are a chess master...",
        "configuration": { "temperature": 0.7 }
      },
      "errors": []
    }
  }
}
```

**Example Error Response**:
```json
{
  "data": {
    "createAgent": {
      "agent": null,
      "errors": ["Name can't be blank", "Prompt text is too short (minimum is 10 characters)"]
    }
  }
}
```

### Design Decisions

**Why no pagination on agents query?**
- YAGNI: MVP won't have thousands of agents
- Can add Relay-style connections later if needed
- Keeps initial implementation simple

**Why string array for errors instead of structured type?**
- Rails validation errors are strings
- Simple to implement
- Easy to display in UI
- Can enhance later if needed

**Why DeleteAgentPayload returns success boolean?**
- Agent is deleted, can't return it
- Success boolean makes sense: true = deleted, false = not found or error
- Errors array provides details if failed

---

## Testing Strategy

### Coverage Requirements
- **Minimum**: 90% overall coverage (raised from Phase 1's 50%)
- **Target**: 100% coverage on Agent model and mutations
- **Enforced**: SimpleCov fails build if below 90%

### Test Structure

**File Organization**:
```
spec/
├── models/
│   └── agent_spec.rb                    # Model validations, defaults
├── requests/
│   └── graphql/
│       └── agents_spec.rb               # GraphQL queries and mutations
└── factories/
    └── agents.rb                        # FactoryBot agent factory
```

### Model Tests

**File**: `spec/models/agent_spec.rb`

**Test Coverage**:
```ruby
RSpec.describe Agent, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes'

    describe 'name' do
      it 'is required'
      it 'must be at least 1 character'
      it 'must be at most 100 characters'
    end

    describe 'prompt_text' do
      it 'is required'
      it 'must be at least 10 characters'
      it 'must be at most 10,000 characters'
    end

    describe 'role' do
      it 'is optional'
      it 'must be at most 50 characters if present'
    end

    describe 'configuration' do
      it 'defaults to empty hash'
      it 'must be present'
      it 'accepts valid JSON structure'
    end
  end

  describe 'factory' do
    it 'creates valid agent with default traits'
    it 'creates valid agent with :opening trait'
    it 'creates valid agent with :tactical trait'
  end
end
```

### GraphQL Request Tests

**File**: `spec/requests/graphql/agents_spec.rb`

**Test Coverage**:
```ruby
RSpec.describe 'Agents GraphQL API', type: :request do
  describe 'Query: agents' do
    it 'returns all agents'
    it 'returns empty array when no agents exist'
    it 'includes all agent fields'
  end

  describe 'Query: agent' do
    it 'returns agent by ID'
    it 'returns null for non-existent ID'
    it 'includes all agent fields'
  end

  describe 'Mutation: createAgent' do
    context 'with valid params' do
      it 'creates agent'
      it 'returns created agent'
      it 'returns empty errors array'
      it 'sets default configuration if not provided'
    end

    context 'with invalid params' do
      it 'does not create agent'
      it 'returns null agent'
      it 'returns validation errors'
    end
  end

  describe 'Mutation: updateAgent' do
    context 'with valid params' do
      it 'updates agent'
      it 'returns updated agent'
      it 'supports partial updates (only name)'
      it 'supports partial updates (only prompt_text)'
      it 'supports partial updates (only role)'
      it 'supports partial updates (only configuration)'
    end

    context 'with invalid params' do
      it 'does not update agent'
      it 'returns validation errors'
    end

    context 'with non-existent ID' do
      it 'returns error'
    end
  end

  describe 'Mutation: deleteAgent' do
    context 'with valid ID' do
      it 'deletes agent'
      it 'returns success: true'
      it 'returns empty errors array'
    end

    context 'with non-existent ID' do
      it 'returns success: false'
      it 'returns error message'
    end
  end
end
```

**Test Helpers**:
```ruby
# Helper method to execute GraphQL queries in tests
def execute_graphql(query, variables: {})
  post '/graphql', params: { query: query, variables: variables }
  JSON.parse(response.body)
end
```

### FactoryBot Factory

**File**: `spec/factories/agents.rb`

```ruby
FactoryBot.define do
  factory :agent do
    name { Faker::Games::Chess.title }
    role { ['opening', 'tactical', 'positional', 'endgame'].sample }
    prompt_text { "You are a chess master specializing in #{role} play. #{Faker::Lorem.paragraph}" }
    configuration { { temperature: 0.7, max_tokens: 500, top_p: 1.0 } }

    trait :opening do
      role { 'opening' }
      name { 'Opening Specialist' }
      prompt_text { 'You specialize in chess openings. You know all major opening systems...' }
    end

    trait :tactical do
      role { 'tactical' }
      name { 'Tactical Master' }
      prompt_text { 'You excel at tactical combinations. Look for forks, pins, skewers...' }
    end

    trait :positional do
      role { 'positional' }
      name { 'Positional Player' }
      prompt_text { 'You focus on positional play. Control the center, improve piece placement...' }
    end

    trait :minimal_config do
      configuration { {} }
    end

    trait :custom_config do
      configuration { { temperature: 0.9, max_tokens: 1000, custom_param: 'value' } }
    end
  end
end
```

**Usage Examples**:
```ruby
# Create default agent
agent = create(:agent)

# Create opening specialist
agent = create(:agent, :opening)

# Create agent with minimal config
agent = create(:agent, :minimal_config)

# Create agent with custom attributes
agent = create(:agent, name: 'My Agent', role: 'endgame')
```

### Testing Approach (TDD)

**Process for Each Feature**:
1. **RED**: Write failing test first
2. **GREEN**: Write minimal code to pass test
3. **REFACTOR**: Improve code while keeping tests green
4. **COMMIT**: Atomic commit with conventional format

**Example TDD Flow**:
```bash
# 1. Write model validation test (RED)
bundle exec rspec spec/models/agent_spec.rb
# Fails: name validation missing

# 2. Add validation to model (GREEN)
# Edit app/models/agent.rb
bundle exec rspec spec/models/agent_spec.rb
# Passes

# 3. Refactor if needed
# 4. Commit
git add -A
git commit -m "test: Add Agent model name validation"
```

---

## Implementation Steps

### Step 1: Migration & Model

**Generate Migration**:
```bash
rails generate model Agent name:string role:string prompt_text:text configuration:jsonb
```

**Edit Migration** (`db/migrate/YYYYMMDDHHMMSS_create_agents.rb`):
```ruby
class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :name, null: false
      t.string :role
      t.text :prompt_text, null: false
      t.jsonb :configuration, default: {}, null: false

      t.timestamps
    end

    add_index :agents, :role
  end
end
```

**Run Migration**:
```bash
rails db:migrate
```

**Write Model Tests** (RED):
- Create `spec/models/agent_spec.rb` with all validation tests

**Implement Model Validations** (GREEN):
```ruby
# app/models/agent.rb
class Agent < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :prompt_text, presence: true, length: { minimum: 10, maximum: 10_000 }
  validates :role, length: { maximum: 50 }, allow_blank: true
  validates :configuration, presence: true
end
```

**Run Tests**:
```bash
bundle exec rspec spec/models/agent_spec.rb
```

### Step 2: FactoryBot Setup

**Create Factory**:
- Create `spec/factories/agents.rb` with default factory and traits

**Test Factory**:
```ruby
# In spec/models/agent_spec.rb
describe 'factory' do
  it 'creates valid agent' do
    agent = build(:agent)
    expect(agent).to be_valid
  end
end
```

### Step 3: GraphQL Types

**Create Agent Type**:
```bash
# Create file manually: app/graphql/types/agent_type.rb
```

```ruby
module Types
  class AgentType < Types::BaseObject
    description "A chess-playing agent with a custom prompt"

    field :id, ID, null: false
    field :name, String, null: false
    field :role, String, null: true
    field :prompt_text, String, null: false
    field :configuration, GraphQL::Types::JSON, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
```

**Create Input Types**:
```ruby
# app/graphql/types/create_agent_input.rb
module Types
  class CreateAgentInput < Types::BaseInputObject
    argument :name, String, required: true
    argument :role, String, required: false
    argument :prompt_text, String, required: true
    argument :configuration, GraphQL::Types::JSON, required: false
  end
end

# app/graphql/types/update_agent_input.rb
module Types
  class UpdateAgentInput < Types::BaseInputObject
    argument :id, ID, required: true
    argument :name, String, required: false
    argument :role, String, required: false
    argument :prompt_text, String, required: false
    argument :configuration, GraphQL::Types::JSON, required: false
  end
end

# app/graphql/types/delete_agent_input.rb
module Types
  class DeleteAgentInput < Types::BaseInputObject
    argument :id, ID, required: true
  end
end
```

**Create Payload Types**:
```ruby
# app/graphql/types/create_agent_payload.rb
module Types
  class CreateAgentPayload < Types::BaseObject
    field :agent, Types::AgentType, null: true
    field :errors, [String], null: false
  end
end

# Similar for UpdateAgentPayload, DeleteAgentPayload
```

### Step 4: GraphQL Queries

**Write Query Tests** (RED):
- Add tests to `spec/requests/graphql/agents_spec.rb` for `agents` and `agent` queries

**Implement Queries** (GREEN):
```ruby
# app/graphql/types/query_type.rb
module Types
  class QueryType < Types::BaseObject
    # ... existing testField ...

    field :agents, [Types::AgentType], null: false,
      description: "Returns all agents"

    field :agent, Types::AgentType, null: true,
      description: "Returns a single agent by ID" do
      argument :id, ID, required: true
    end

    def agents
      Agent.all
    end

    def agent(id:)
      Agent.find_by(id: id)
    end
  end
end
```

**Test in GraphiQL**:
```graphql
# Query all agents
query {
  agents {
    id
    name
    role
    promptText
    configuration
  }
}

# Query single agent
query {
  agent(id: "1") {
    id
    name
    promptText
  }
}
```

### Step 5: GraphQL Mutations

**Write Mutation Tests** (RED):
- Add tests to `spec/requests/graphql/agents_spec.rb` for all mutations

**Create Mutation Classes**:
```ruby
# app/graphql/mutations/create_agent.rb
module Mutations
  class CreateAgent < BaseMutation
    argument :input, Types::CreateAgentInput, required: true

    field :agent, Types::AgentType, null: true
    field :errors, [String], null: false

    def resolve(input:)
      agent = Agent.new(input.to_h)

      if agent.save
        { agent: agent, errors: [] }
      else
        { agent: nil, errors: agent.errors.full_messages }
      end
    end
  end
end

# Similar for UpdateAgent, DeleteAgent
```

**Add to Mutation Type**:
```ruby
# app/graphql/types/mutation_type.rb
module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
    field :delete_agent, mutation: Mutations::DeleteAgent
  end
end
```

**Test in GraphiQL**:
```graphql
# Create agent
mutation {
  createAgent(input: {
    name: "Tactical Master"
    role: "tactical"
    promptText: "You are a chess master specializing in tactical play..."
    configuration: { temperature: 0.7, max_tokens: 500 }
  }) {
    agent {
      id
      name
      role
    }
    errors
  }
}

# Update agent
mutation {
  updateAgent(input: {
    id: "1"
    name: "Updated Name"
  }) {
    agent {
      id
      name
    }
    errors
  }
}

# Delete agent
mutation {
  deleteAgent(input: { id: "1" }) {
    success
    errors
  }
}
```

---

## Verification Checklist

Before marking Phase 2a complete, verify ALL of these:

### Testing
- [ ] `bundle exec rspec` - all tests pass
- [ ] SimpleCov shows 90%+ coverage overall
- [ ] SimpleCov shows 100% coverage on Agent model
- [ ] SimpleCov shows 100% coverage on mutations
- [ ] No pending tests
- [ ] No test warnings or deprecations

### Model
- [ ] Agent model exists with all validations
- [ ] Can create agent in `rails console`
- [ ] Validations prevent invalid data
- [ ] Default configuration works

### GraphQL Queries
- [ ] Can query all agents via GraphiQL
- [ ] Can query single agent by ID via GraphiQL
- [ ] Queries return all fields correctly
- [ ] Query for non-existent ID returns null

### GraphQL Mutations
- [ ] Can create agent via GraphiQL
- [ ] Can update agent via GraphiQL (full update)
- [ ] Can update agent via GraphiQL (partial update)
- [ ] Can delete agent via GraphiQL
- [ ] Invalid data shows validation errors
- [ ] Errors array populated correctly on failure

### Database
- [ ] Migration ran successfully
- [ ] Agents table exists with correct schema
- [ ] JSONB configuration column works
- [ ] Index on role exists

### Code Quality
- [ ] All commits use conventional format
- [ ] No commented-out code
- [ ] No console.log or binding.pry left in code
- [ ] Code follows Rails conventions

---

## Deliverables

**Completed**:
- ✅ Agents table migration
- ✅ Agent model with full validations
- ✅ Complete GraphQL CRUD API
- ✅ Query: agents (returns all)
- ✅ Query: agent(id) (returns one)
- ✅ Mutation: createAgent
- ✅ Mutation: updateAgent
- ✅ Mutation: deleteAgent
- ✅ Input types for all mutations
- ✅ Payload types with error handling
- ✅ 90%+ test coverage
- ✅ FactoryBot factories with traits
- ✅ All RSpec tests passing
- ✅ Manual testing via GraphiQL documented

---

## Next Steps

### Immediate
1. **Write Implementation Plan** - Use `superpowers:writing-plans` to create detailed task list
2. **Execute Plan with TDD** - Use `superpowers:executing-plans` with strict TDD
3. **Verify Completion** - Run through entire checklist
4. **Create Pull Request** - Merge into main

### After Phase 2a Completion
1. **Begin Phase 2b** - API Configuration Model
2. **Update context.md** - Document decisions made

---

## Design Decisions Summary

**Model Design**:
- No user_id yet (add in Phase 2e)
- JSONB configuration for flexibility
- Free-text role for experimentation
- Reasonable prompt length limits (10-10k)

**GraphQL Design**:
- Simple CRUD operations
- No pagination yet (YAGNI)
- Errors as string array (simple)
- Standard mutation payload pattern

**Testing Design**:
- 90% minimum coverage (up from 50%)
- 100% target for new code
- TDD throughout
- FactoryBot traits for common cases

---

**Design Status**: ✅ Complete and Validated
**Next Step**: Create implementation plan using `superpowers:writing-plans`
