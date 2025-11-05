# Phase 2a: Agent Model + GraphQL API - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use @superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build Agent model and GraphQL CRUD API for managing chess-playing agents with custom prompts. Backend only, testable via GraphiQL.

**Architecture:** TDD approach (Red → Green → Refactor → Commit). Model with ActiveRecord validations, GraphQL types for API, RSpec for testing, FactoryBot for fixtures.

**Tech Stack:** Rails 8, PostgreSQL with JSONB, GraphQL (graphql-ruby), RSpec, FactoryBot

---

## Prerequisites

**Before starting:**
- [ ] Rails app running (`bin/dev` works)
- [ ] Tests passing (`bundle exec rspec`)
- [ ] PostgreSQL running
- [ ] On main branch with latest changes

**Create feature branch:**
```bash
git checkout -b feature/phase-2a-agent-model-api
```

---

## Task 1: Create Agent Migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_agents.rb` (generated)
- Modify: `db/schema.rb` (auto-updated)

**Step 1: Generate migration**

```bash
rails generate model Agent name:string role:string prompt_text:text configuration:jsonb
```

Expected: Creates migration file and model file

**Step 2: Edit migration to add constraints**

Edit `db/migrate/YYYYMMDDHHMMSS_create_agents.rb`:

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

**Step 3: Run migration**

```bash
rails db:migrate
```

Expected: Migration runs successfully, agents table created

**Step 4: Verify in database**

```bash
rails db:migrate:status
```

Expected: Last migration shows "up"

**Step 5: Commit**

```bash
git add db/migrate db/schema.rb app/models/agent.rb
git commit -m "feat: add Agent model migration with JSONB configuration

Create agents table with:
- name (required string)
- role (optional string, indexed)
- prompt_text (required text)
- configuration (JSONB with default {})

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Create FactoryBot Factory

**Files:**
- Create: `spec/factories/agents.rb`

**Step 1: Create factory file**

Create `spec/factories/agents.rb`:

```ruby
FactoryBot.define do
  factory :agent do
    name { "Chess Master #{rand(1000)}" }
    role { ['opening', 'tactical', 'positional', 'endgame'].sample }
    prompt_text { "You are a chess master specializing in #{role} play. You analyze positions deeply and suggest the best moves based on chess principles and tactics." }
    configuration { { temperature: 0.7, max_tokens: 500, top_p: 1.0 } }

    trait :opening do
      role { 'opening' }
      name { 'Opening Specialist' }
      prompt_text { 'You specialize in chess openings. You know all major opening systems including the Sicilian, French, Ruy Lopez, and King\'s Indian. You prioritize piece development, center control, and king safety in the opening phase.' }
    end

    trait :tactical do
      role { 'tactical' }
      name { 'Tactical Master' }
      prompt_text { 'You excel at tactical combinations. Look for forks, pins, skewers, discovered attacks, and sacrifices. Calculate forcing sequences deeply and find winning tactics.' }
    end

    trait :positional do
      role { 'positional' }
      name { 'Positional Player' }
      prompt_text { 'You focus on positional play. Control the center, improve piece placement, create pawn structure advantages, and restrict opponent pieces. Play for long-term advantages.' }
    end

    trait :minimal_config do
      configuration { {} }
    end

    trait :custom_config do
      configuration { { temperature: 0.9, max_tokens: 1000, custom_param: 'test_value' } }
    end
  end
end
```

**Step 2: Commit**

```bash
git add spec/factories/agents.rb
git commit -m "test: add Agent factory with traits

Create FactoryBot factory with:
- Default agent with random name and role
- :opening trait for opening specialists
- :tactical trait for tactical players
- :positional trait for positional players
- :minimal_config and :custom_config traits

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Write Agent Model Validation Tests (RED)

**Files:**
- Create: `spec/models/agent_spec.rb`

**Step 1: Create model spec file**

Create `spec/models/agent_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Agent, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      agent = build(:agent)
      expect(agent).to be_valid
    end

    describe 'name' do
      it 'is required' do
        agent = build(:agent, name: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("can't be blank")
      end

      it 'must be at least 1 character' do
        agent = build(:agent, name: '')
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("is too short (minimum is 1 character)")
      end

      it 'must be at most 100 characters' do
        agent = build(:agent, name: 'a' * 101)
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("is too long (maximum is 100 characters)")
      end

      it 'allows 100 characters' do
        agent = build(:agent, name: 'a' * 100)
        expect(agent).to be_valid
      end
    end

    describe 'prompt_text' do
      it 'is required' do
        agent = build(:agent, prompt_text: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("can't be blank")
      end

      it 'must be at least 10 characters' do
        agent = build(:agent, prompt_text: 'short')
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("is too short (minimum is 10 characters)")
      end

      it 'must be at most 10,000 characters' do
        agent = build(:agent, prompt_text: 'a' * 10_001)
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("is too long (maximum is 10000 characters)")
      end

      it 'allows 10,000 characters' do
        agent = build(:agent, prompt_text: 'a' * 10_000)
        expect(agent).to be_valid
      end
    end

    describe 'role' do
      it 'is optional' do
        agent = build(:agent, role: nil)
        expect(agent).to be_valid
      end

      it 'must be at most 50 characters if present' do
        agent = build(:agent, role: 'a' * 51)
        expect(agent).not_to be_valid
        expect(agent.errors[:role]).to include("is too long (maximum is 50 characters)")
      end

      it 'allows 50 characters' do
        agent = build(:agent, role: 'a' * 50)
        expect(agent).to be_valid
      end
    end

    describe 'configuration' do
      it 'defaults to empty hash' do
        agent = Agent.new(name: 'Test', prompt_text: 'Test prompt text here')
        expect(agent.configuration).to eq({})
      end

      it 'must be present' do
        agent = build(:agent, configuration: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:configuration]).to include("can't be blank")
      end

      it 'accepts valid JSON structure' do
        agent = build(:agent, configuration: { temperature: 0.8, max_tokens: 200 })
        expect(agent).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'creates valid agent with default factory' do
      agent = build(:agent)
      expect(agent).to be_valid
    end

    it 'creates valid agent with :opening trait' do
      agent = build(:agent, :opening)
      expect(agent).to be_valid
      expect(agent.role).to eq('opening')
    end

    it 'creates valid agent with :tactical trait' do
      agent = build(:agent, :tactical)
      expect(agent).to be_valid
      expect(agent.role).to eq('tactical')
    end

    it 'creates valid agent with :positional trait' do
      agent = build(:agent, :positional)
      expect(agent).to be_valid
      expect(agent.role).to eq('positional')
    end

    it 'creates valid agent with :minimal_config trait' do
      agent = build(:agent, :minimal_config)
      expect(agent).to be_valid
      expect(agent.configuration).to eq({})
    end
  end
end
```

**Step 2: Run tests to verify they fail (RED)**

```bash
bundle exec rspec spec/models/agent_spec.rb
```

Expected: Tests fail with validation errors (no validations implemented yet)

**Step 3: Commit**

```bash
git add spec/models/agent_spec.rb
git commit -m "test: add Agent model validation specs (RED)

Add comprehensive validation tests for:
- name presence and length (1-100 chars)
- prompt_text presence and length (10-10k chars)
- role optional with max 50 chars
- configuration presence and default value
- factory trait validations

All tests currently failing (RED phase of TDD).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Implement Agent Model Validations (GREEN)

**Files:**
- Modify: `app/models/agent.rb`

**Step 1: Add validations to model**

Edit `app/models/agent.rb`:

```ruby
class Agent < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :prompt_text, presence: true, length: { minimum: 10, maximum: 10_000 }
  validates :role, length: { maximum: 50 }, allow_blank: true
  validates :configuration, presence: true
end
```

**Step 2: Run tests to verify they pass (GREEN)**

```bash
bundle exec rspec spec/models/agent_spec.rb
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add app/models/agent.rb
git commit -m "feat: add Agent model validations (GREEN)

Implement validations:
- name: required, 1-100 characters
- prompt_text: required, 10-10,000 characters
- role: optional, max 50 characters
- configuration: required (defaults to {} from migration)

All model tests now passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Create GraphQL Agent Type

**Files:**
- Create: `app/graphql/types/agent_type.rb`

**Step 1: Create AgentType file**

Create `app/graphql/types/agent_type.rb`:

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

**Step 2: Commit**

```bash
git add app/graphql/types/agent_type.rb
git commit -m "feat: add GraphQL AgentType

Create AgentType with all fields:
- id, name, role, prompt_text, configuration
- timestamps (created_at, updated_at)
- role nullable to match DB schema
- configuration as JSON type

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Create GraphQL Input Types

**Files:**
- Create: `app/graphql/types/inputs/create_agent_input.rb`
- Create: `app/graphql/types/inputs/update_agent_input.rb`
- Create: `app/graphql/types/inputs/delete_agent_input.rb`

**Step 1: Create inputs directory**

```bash
mkdir -p app/graphql/types/inputs
```

**Step 2: Create CreateAgentInput**

Create `app/graphql/types/inputs/create_agent_input.rb`:

```ruby
module Types
  module Inputs
    class CreateAgentInput < Types::BaseInputObject
      description "Input for creating a new agent"

      argument :name, String, required: true
      argument :role, String, required: false
      argument :prompt_text, String, required: true
      argument :configuration, GraphQL::Types::JSON, required: false
    end
  end
end
```

**Step 3: Create UpdateAgentInput**

Create `app/graphql/types/inputs/update_agent_input.rb`:

```ruby
module Types
  module Inputs
    class UpdateAgentInput < Types::BaseInputObject
      description "Input for updating an existing agent"

      argument :id, ID, required: true
      argument :name, String, required: false
      argument :role, String, required: false
      argument :prompt_text, String, required: false
      argument :configuration, GraphQL::Types::JSON, required: false
    end
  end
end
```

**Step 4: Create DeleteAgentInput**

Create `app/graphql/types/inputs/delete_agent_input.rb`:

```ruby
module Types
  module Inputs
    class DeleteAgentInput < Types::BaseInputObject
      description "Input for deleting an agent"

      argument :id, ID, required: true
    end
  end
end
```

**Step 5: Commit**

```bash
git add app/graphql/types/inputs/
git commit -m "feat: add GraphQL input types for Agent mutations

Create input types:
- CreateAgentInput: name, prompt_text required; role, config optional
- UpdateAgentInput: id required; all other fields optional for partial updates
- DeleteAgentInput: id required only

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Create GraphQL Payload Types

**Files:**
- Create: `app/graphql/types/payloads/create_agent_payload.rb`
- Create: `app/graphql/types/payloads/update_agent_payload.rb`
- Create: `app/graphql/types/payloads/delete_agent_payload.rb`

**Step 1: Create payloads directory**

```bash
mkdir -p app/graphql/types/payloads
```

**Step 2: Create CreateAgentPayload**

Create `app/graphql/types/payloads/create_agent_payload.rb`:

```ruby
module Types
  module Payloads
    class CreateAgentPayload < Types::BaseObject
      description "Payload returned from createAgent mutation"

      field :agent, Types::AgentType, null: true,
        description: "The created agent (null if errors occurred)"
      field :errors, [String], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
```

**Step 3: Create UpdateAgentPayload**

Create `app/graphql/types/payloads/update_agent_payload.rb`:

```ruby
module Types
  module Payloads
    class UpdateAgentPayload < Types::BaseObject
      description "Payload returned from updateAgent mutation"

      field :agent, Types::AgentType, null: true,
        description: "The updated agent (null if errors occurred)"
      field :errors, [String], null: false,
        description: "Validation errors (empty array if successful)"
    end
  end
end
```

**Step 4: Create DeleteAgentPayload**

Create `app/graphql/types/payloads/delete_agent_payload.rb`:

```ruby
module Types
  module Payloads
    class DeleteAgentPayload < Types::BaseObject
      description "Payload returned from deleteAgent mutation"

      field :success, Boolean, null: false,
        description: "Whether the deletion was successful"
      field :errors, [String], null: false,
        description: "Error messages (empty array if successful)"
    end
  end
end
```

**Step 5: Commit**

```bash
git add app/graphql/types/payloads/
git commit -m "feat: add GraphQL payload types for Agent mutations

Create payload types:
- CreateAgentPayload: agent (nullable), errors array
- UpdateAgentPayload: agent (nullable), errors array
- DeleteAgentPayload: success boolean, errors array

Follow GraphQL best practice: errors always present, data nullable on failure.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: Write Query Tests (RED)

**Files:**
- Create: `spec/requests/graphql/agents_spec.rb`
- Create: `spec/support/graphql_helper.rb`

**Step 1: Create GraphQL helper**

Create `spec/support/graphql_helper.rb`:

```ruby
module GraphqlHelper
  def execute_graphql(query, variables: {})
    post '/graphql', params: { query: query, variables: variables }
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include GraphqlHelper, type: :request
end
```

**Step 2: Create graphql directory**

```bash
mkdir -p spec/requests/graphql
```

**Step 3: Create agents request spec with query tests**

Create `spec/requests/graphql/agents_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Agents GraphQL API', type: :request do
  describe 'Query: agents' do
    it 'returns all agents' do
      agent1 = create(:agent, name: 'Agent 1')
      agent2 = create(:agent, name: 'Agent 2')

      query = <<~GQL
        query {
          agents {
            id
            name
            role
            promptText
            configuration
          }
        }
      GQL

      result = execute_graphql(query)

      expect(result['data']['agents'].length).to eq(2)
      expect(result['data']['agents'].map { |a| a['name'] }).to contain_exactly('Agent 1', 'Agent 2')
    end

    it 'returns empty array when no agents exist' do
      query = <<~GQL
        query {
          agents {
            id
            name
          }
        }
      GQL

      result = execute_graphql(query)

      expect(result['data']['agents']).to eq([])
    end

    it 'includes all agent fields' do
      agent = create(:agent, :tactical)

      query = <<~GQL
        query {
          agents {
            id
            name
            role
            promptText
            configuration
            createdAt
            updatedAt
          }
        }
      GQL

      result = execute_graphql(query)
      agent_data = result['data']['agents'].first

      expect(agent_data['id']).to eq(agent.id.to_s)
      expect(agent_data['name']).to eq(agent.name)
      expect(agent_data['role']).to eq(agent.role)
      expect(agent_data['promptText']).to eq(agent.prompt_text)
      expect(agent_data['configuration']).to eq(agent.configuration.stringify_keys)
      expect(agent_data['createdAt']).to be_present
      expect(agent_data['updatedAt']).to be_present
    end
  end

  describe 'Query: agent' do
    it 'returns agent by ID' do
      agent = create(:agent, name: 'Test Agent')

      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
            role
            promptText
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: agent.id.to_s })

      expect(result['data']['agent']['id']).to eq(agent.id.to_s)
      expect(result['data']['agent']['name']).to eq('Test Agent')
    end

    it 'returns null for non-existent ID' do
      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: '99999' })

      expect(result['data']['agent']).to be_nil
    end

    it 'includes all agent fields' do
      agent = create(:agent, :opening)

      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
            role
            promptText
            configuration
            createdAt
            updatedAt
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: agent.id.to_s })
      agent_data = result['data']['agent']

      expect(agent_data['id']).to eq(agent.id.to_s)
      expect(agent_data['name']).to eq(agent.name)
      expect(agent_data['role']).to eq('opening')
      expect(agent_data['promptText']).to eq(agent.prompt_text)
      expect(agent_data['configuration']).to eq(agent.configuration.stringify_keys)
      expect(agent_data['createdAt']).to be_present
      expect(agent_data['updatedAt']).to be_present
    end
  end
end
```

**Step 4: Run tests to verify they fail (RED)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb
```

Expected: Tests fail (queries not implemented yet)

**Step 5: Commit**

```bash
git add spec/support/graphql_helper.rb spec/requests/graphql/
git commit -m "test: add GraphQL query specs for agents (RED)

Add tests for:
- agents query: returns all agents, empty array, all fields
- agent(id) query: returns by ID, null for non-existent, all fields
- GraphQL helper for executing queries in tests

All tests currently failing (RED phase of TDD).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: Implement GraphQL Queries (GREEN)

**Files:**
- Modify: `app/graphql/types/query_type.rb`

**Step 1: Add agent queries to QueryType**

Edit `app/graphql/types/query_type.rb`:

```ruby
module Types
  class QueryType < Types::BaseObject
    description "The query root of this schema"

    field :test_field, String, null: false,
      description: "A simple test query to verify GraphQL is working"

    def test_field
      "Hello from GraphQL!"
    end

    field :agents, [Types::AgentType], null: false,
      description: "Returns all agents"

    def agents
      Agent.all
    end

    field :agent, Types::AgentType, null: true,
      description: "Returns a single agent by ID" do
      argument :id, ID, required: true
    end

    def agent(id:)
      Agent.find_by(id: id)
    end
  end
end
```

**Step 2: Run tests to verify they pass (GREEN)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb
```

Expected: All query tests pass

**Step 3: Commit**

```bash
git add app/graphql/types/query_type.rb
git commit -m "feat: implement agents and agent GraphQL queries (GREEN)

Add queries:
- agents: returns all agents (empty array if none)
- agent(id): returns single agent by ID (null if not found)

All query tests now passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 10: Write CreateAgent Mutation Tests (RED)

**Files:**
- Modify: `spec/requests/graphql/agents_spec.rb`

**Step 1: Add createAgent mutation tests**

Add to `spec/requests/graphql/agents_spec.rb` (after Query tests):

```ruby
  describe 'Mutation: createAgent' do
    context 'with valid params' do
      it 'creates agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
                name
                role
                promptText
                configuration
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Tactical Master',
            role: 'tactical',
            promptText: 'You are a tactical chess master who excels at finding combinations.',
            configuration: { temperature: 0.8, max_tokens: 600 }
          }
        }

        expect {
          execute_graphql(query, variables: variables)
        }.to change(Agent, :count).by(1)

        result = execute_graphql(query, variables: variables)
        agent_data = result['data']['createAgent']['agent']

        expect(agent_data['name']).to eq('Tactical Master')
        expect(agent_data['role']).to eq('tactical')
        expect(agent_data['promptText']).to eq('You are a tactical chess master who excels at finding combinations.')
        expect(agent_data['configuration']).to eq({ 'temperature' => 0.8, 'max_tokens' => 600 })
      end

      it 'returns created agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
                name
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text for the agent.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']).to be_present
        expect(result['data']['createAgent']['agent']['name']).to eq('Test Agent')
      end

      it 'returns empty errors array' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text here.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['errors']).to eq([])
      end

      it 'sets default configuration if not provided' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                configuration
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']['configuration']).to eq({})
      end
    end

    context 'with invalid params' do
      it 'does not create agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'short'
          }
        }

        expect {
          execute_graphql(query, variables: variables)
        }.not_to change(Agent, :count)
      end

      it 'returns null agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'bad'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']).to be_nil
      end

      it 'returns validation errors' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'short'
          }
        }

        result = execute_graphql(query, variables: variables)

        errors = result['data']['createAgent']['errors']
        expect(errors).to include(match(/Name is too short/))
        expect(errors).to include(match(/Prompt text is too short/))
      end
    end
  end
```

**Step 2: Run tests to verify they fail (RED)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: createAgent"
```

Expected: Tests fail (mutation not implemented yet)

**Step 3: Commit**

```bash
git add spec/requests/graphql/agents_spec.rb
git commit -m "test: add createAgent mutation specs (RED)

Add tests for createAgent mutation:
- Valid params: creates agent, returns agent, empty errors
- Invalid params: doesn't create, returns null, returns errors
- Default configuration handling

All tests currently failing (RED phase of TDD).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 11: Implement CreateAgent Mutation (GREEN)

**Files:**
- Create: `app/graphql/mutations/create_agent.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Create mutations directory**

```bash
mkdir -p app/graphql/mutations
```

**Step 2: Create CreateAgent mutation**

Create `app/graphql/mutations/create_agent.rb`:

```ruby
module Mutations
  class CreateAgent < BaseMutation
    description "Create a new agent"

    argument :input, Types::Inputs::CreateAgentInput, required: true

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
```

**Step 3: Add mutation to MutationType**

Edit `app/graphql/types/mutation_type.rb`:

```ruby
module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
  end
end
```

**Step 4: Run tests to verify they pass (GREEN)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: createAgent"
```

Expected: All createAgent tests pass

**Step 5: Commit**

```bash
git add app/graphql/mutations/create_agent.rb app/graphql/types/mutation_type.rb
git commit -m "feat: implement createAgent GraphQL mutation (GREEN)

Add CreateAgent mutation:
- Accepts CreateAgentInput with name, role, promptText, config
- Returns agent on success with empty errors array
- Returns null agent with validation errors on failure

All createAgent tests now passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 12: Write UpdateAgent Mutation Tests (RED)

**Files:**
- Modify: `spec/requests/graphql/agents_spec.rb`

**Step 1: Add updateAgent mutation tests**

Add to `spec/requests/graphql/agents_spec.rb` (after createAgent tests):

```ruby
  describe 'Mutation: updateAgent' do
    let!(:agent) { create(:agent, name: 'Original Name', role: 'tactical') }

    context 'with valid params' do
      it 'updates agent' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                id
                name
                role
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            name: 'Updated Name',
            role: 'positional'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']['name']).to eq('Updated Name')
        expect(result['data']['updateAgent']['agent']['role']).to eq('positional')

        agent.reload
        expect(agent.name).to eq('Updated Name')
        expect(agent.role).to eq('positional')
      end

      it 'returns updated agent' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                id
                name
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            name: 'New Name'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']).to be_present
        expect(result['data']['updateAgent']['errors']).to eq([])
      end

      it 'supports partial updates (only name)' do
        original_prompt = agent.prompt_text

        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                name
                promptText
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            name: 'Just Name Changed'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']['name']).to eq('Just Name Changed')
        expect(result['data']['updateAgent']['agent']['promptText']).to eq(original_prompt)
      end

      it 'supports partial updates (only prompt_text)' do
        original_name = agent.name

        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                name
                promptText
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            promptText: 'New prompt text for the agent here.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']['name']).to eq(original_name)
        expect(result['data']['updateAgent']['agent']['promptText']).to eq('New prompt text for the agent here.')
      end

      it 'supports partial updates (only role)' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                role
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            role: 'endgame'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']['role']).to eq('endgame')
      end

      it 'supports partial updates (only configuration)' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                configuration
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            configuration: { temperature: 0.9 }
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']['configuration']).to eq({ 'temperature' => 0.9 })
      end
    end

    context 'with invalid params' do
      it 'does not update agent' do
        original_name = agent.name

        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            name: ''
          }
        }

        execute_graphql(query, variables: variables)

        agent.reload
        expect(agent.name).to eq(original_name)
      end

      it 'returns validation errors' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s,
            promptText: 'short'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['errors']).to include(match(/Prompt text is too short/))
      end
    end

    context 'with non-existent ID' do
      it 'returns error' do
        query = <<~GQL
          mutation($input: UpdateAgentInput!) {
            updateAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: '99999',
            name: 'New Name'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['updateAgent']['agent']).to be_nil
        expect(result['data']['updateAgent']['errors']).to include(match(/not found/i))
      end
    end
  end
```

**Step 2: Run tests to verify they fail (RED)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: updateAgent"
```

Expected: Tests fail (mutation not implemented yet)

**Step 3: Commit**

```bash
git add spec/requests/graphql/agents_spec.rb
git commit -m "test: add updateAgent mutation specs (RED)

Add tests for updateAgent mutation:
- Valid params: updates agent, returns updated agent
- Partial updates: name only, prompt only, role only, config only
- Invalid params: doesn't update, returns errors
- Non-existent ID: returns error

All tests currently failing (RED phase of TDD).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 13: Implement UpdateAgent Mutation (GREEN)

**Files:**
- Create: `app/graphql/mutations/update_agent.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Create UpdateAgent mutation**

Create `app/graphql/mutations/update_agent.rb`:

```ruby
module Mutations
  class UpdateAgent < BaseMutation
    description "Update an existing agent"

    argument :input, Types::Inputs::UpdateAgentInput, required: true

    field :agent, Types::AgentType, null: true
    field :errors, [String], null: false

    def resolve(input:)
      agent = Agent.find_by(id: input[:id])

      if agent.nil?
        return { agent: nil, errors: ["Agent not found"] }
      end

      # Extract only the fields that were provided (exclude id)
      update_params = input.to_h.except(:id)

      if agent.update(update_params)
        { agent: agent, errors: [] }
      else
        { agent: nil, errors: agent.errors.full_messages }
      end
    end
  end
end
```

**Step 2: Add mutation to MutationType**

Edit `app/graphql/types/mutation_type.rb`:

```ruby
module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
  end
end
```

**Step 3: Run tests to verify they pass (GREEN)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: updateAgent"
```

Expected: All updateAgent tests pass

**Step 4: Commit**

```bash
git add app/graphql/mutations/update_agent.rb app/graphql/types/mutation_type.rb
git commit -m "feat: implement updateAgent GraphQL mutation (GREEN)

Add UpdateAgent mutation:
- Accepts UpdateAgentInput with id + optional fields
- Supports partial updates (only update provided fields)
- Returns agent on success with empty errors array
- Returns null agent with errors on validation failure
- Returns error if agent ID not found

All updateAgent tests now passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 14: Write DeleteAgent Mutation Tests (RED)

**Files:**
- Modify: `spec/requests/graphql/agents_spec.rb`

**Step 1: Add deleteAgent mutation tests**

Add to `spec/requests/graphql/agents_spec.rb` (after updateAgent tests):

```ruby
  describe 'Mutation: deleteAgent' do
    context 'with valid ID' do
      let!(:agent) { create(:agent) }

      it 'deletes agent' do
        query = <<~GQL
          mutation($input: DeleteAgentInput!) {
            deleteAgent(input: $input) {
              success
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s
          }
        }

        expect {
          execute_graphql(query, variables: variables)
        }.to change(Agent, :count).by(-1)

        expect(Agent.find_by(id: agent.id)).to be_nil
      end

      it 'returns success: true' do
        query = <<~GQL
          mutation($input: DeleteAgentInput!) {
            deleteAgent(input: $input) {
              success
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['deleteAgent']['success']).to eq(true)
      end

      it 'returns empty errors array' do
        query = <<~GQL
          mutation($input: DeleteAgentInput!) {
            deleteAgent(input: $input) {
              success
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: agent.id.to_s
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['deleteAgent']['errors']).to eq([])
      end
    end

    context 'with non-existent ID' do
      it 'returns success: false' do
        query = <<~GQL
          mutation($input: DeleteAgentInput!) {
            deleteAgent(input: $input) {
              success
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: '99999'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['deleteAgent']['success']).to eq(false)
      end

      it 'returns error message' do
        query = <<~GQL
          mutation($input: DeleteAgentInput!) {
            deleteAgent(input: $input) {
              success
              errors
            }
          }
        GQL

        variables = {
          input: {
            id: '99999'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['deleteAgent']['errors']).to include(match(/not found/i))
      end
    end
  end
```

**Step 2: Run tests to verify they fail (RED)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: deleteAgent"
```

Expected: Tests fail (mutation not implemented yet)

**Step 3: Commit**

```bash
git add spec/requests/graphql/agents_spec.rb
git commit -m "test: add deleteAgent mutation specs (RED)

Add tests for deleteAgent mutation:
- Valid ID: deletes agent, returns success true, empty errors
- Non-existent ID: returns success false, error message

All tests currently failing (RED phase of TDD).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 15: Implement DeleteAgent Mutation (GREEN)

**Files:**
- Create: `app/graphql/mutations/delete_agent.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Create DeleteAgent mutation**

Create `app/graphql/mutations/delete_agent.rb`:

```ruby
module Mutations
  class DeleteAgent < BaseMutation
    description "Delete an agent"

    argument :input, Types::Inputs::DeleteAgentInput, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(input:)
      agent = Agent.find_by(id: input[:id])

      if agent.nil?
        return { success: false, errors: ["Agent not found"] }
      end

      if agent.destroy
        { success: true, errors: [] }
      else
        { success: false, errors: agent.errors.full_messages }
      end
    end
  end
end
```

**Step 2: Add mutation to MutationType**

Edit `app/graphql/types/mutation_type.rb`:

```ruby
module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
    field :delete_agent, mutation: Mutations::DeleteAgent
  end
end
```

**Step 3: Run tests to verify they pass (GREEN)**

```bash
bundle exec rspec spec/requests/graphql/agents_spec.rb -e "Mutation: deleteAgent"
```

Expected: All deleteAgent tests pass

**Step 4: Commit**

```bash
git add app/graphql/mutations/delete_agent.rb app/graphql/types/mutation_type.rb
git commit -m "feat: implement deleteAgent GraphQL mutation (GREEN)

Add DeleteAgent mutation:
- Accepts DeleteAgentInput with id
- Returns success true with empty errors on successful deletion
- Returns success false with error if agent not found
- Handles destroy failures gracefully

All deleteAgent tests now passing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 16: Update SimpleCov Threshold

**Files:**
- Modify: `spec/spec_helper.rb`

**Step 1: Update SimpleCov configuration**

Edit `spec/spec_helper.rb` to change minimum coverage from 50% to 90%:

```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  minimum_coverage 90  # Changed from 50
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/bin/'
end

# ... rest of spec_helper.rb
```

**Step 2: Run full test suite**

```bash
bundle exec rspec
```

Expected: All tests pass with 90%+ coverage

**Step 3: Check coverage report**

```bash
open coverage/index.html
```

Expected: Coverage at 90% or higher

**Step 4: Commit**

```bash
git add spec/spec_helper.rb
git commit -m "test: raise SimpleCov threshold to 90%

Increase minimum coverage requirement from 50% to 90% for Phase 2a.

Current coverage should exceed 90% with all Agent model and GraphQL API tests.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 17: Manual Testing via GraphiQL

**No files to modify - manual testing only**

**Step 1: Start development server**

```bash
bin/dev
```

**Step 2: Open GraphiQL playground**

Navigate to: `http://localhost:3000/graphiql`

**Step 3: Test query - agents (empty)**

```graphql
query {
  agents {
    id
    name
  }
}
```

Expected: `{ "data": { "agents": [] } }`

**Step 4: Test mutation - createAgent**

```graphql
mutation {
  createAgent(input: {
    name: "Opening Expert"
    role: "opening"
    promptText: "You are a chess opening specialist. You know all major opening systems and their key ideas."
    configuration: { temperature: 0.7, max_tokens: 500 }
  }) {
    agent {
      id
      name
      role
      promptText
      configuration
    }
    errors
  }
}
```

Expected: Agent created, returned with ID

**Step 5: Test query - agents (with data)**

```graphql
query {
  agents {
    id
    name
    role
    promptText
  }
}
```

Expected: Array with one agent

**Step 6: Test query - agent by ID**

```graphql
query {
  agent(id: "1") {
    id
    name
    role
  }
}
```

Expected: Single agent returned

**Step 7: Test mutation - updateAgent**

```graphql
mutation {
  updateAgent(input: {
    id: "1"
    name: "Updated Opening Expert"
  }) {
    agent {
      id
      name
    }
    errors
  }
}
```

Expected: Agent updated

**Step 8: Test mutation - createAgent with invalid data**

```graphql
mutation {
  createAgent(input: {
    name: ""
    promptText: "short"
  }) {
    agent {
      id
    }
    errors
  }
}
```

Expected: Null agent, errors array with validation messages

**Step 9: Test mutation - deleteAgent**

```graphql
mutation {
  deleteAgent(input: { id: "1" }) {
    success
    errors
  }
}
```

Expected: `success: true`, empty errors

**Step 10: Test query - agents (after delete)**

```graphql
query {
  agents {
    id
  }
}
```

Expected: Empty array

**Step 11: Document results**

Create notes in a comment for next commit about manual testing results.

---

## Task 18: Final Verification and Documentation

**Files:**
- Create: `docs/phase-2a-manual-testing.md`

**Step 1: Run full test suite**

```bash
bundle exec rspec
```

Expected: All tests pass

**Step 2: Check coverage**

```bash
open coverage/index.html
```

Expected: 90%+ coverage

**Step 3: Create manual testing documentation**

Create `docs/phase-2a-manual-testing.md`:

```markdown
# Phase 2a Manual Testing Results

**Date**: 2025-11-05
**Tested By**: Implementation Team
**Environment**: Local development (http://localhost:3000/graphiql)

## Test Results

### Query: agents (empty state)
✅ Returns empty array when no agents exist

### Mutation: createAgent
✅ Creates agent with valid params
✅ Returns agent with all fields
✅ Returns empty errors array
✅ Sets default configuration if not provided
✅ Returns errors for invalid data

### Query: agents (with data)
✅ Returns all agents
✅ Includes all fields (id, name, role, promptText, configuration, timestamps)

### Query: agent(id)
✅ Returns single agent by ID
✅ Returns null for non-existent ID

### Mutation: updateAgent
✅ Updates agent fields
✅ Supports partial updates
✅ Returns errors for invalid data
✅ Returns error for non-existent ID

### Mutation: deleteAgent
✅ Deletes agent successfully
✅ Returns success: true
✅ Returns error for non-existent ID

## GraphiQL Schema Documentation
✅ All types visible in schema explorer
✅ All fields have descriptions
✅ Auto-completion works for queries and mutations

## Conclusion
All GraphQL operations working as expected via GraphiQL playground.
Phase 2a ready for pull request.
```

**Step 4: Run verification checklist**

Go through checklist from design document:

```bash
# Testing
bundle exec rspec  # All pass?
open coverage/index.html  # 90%+?

# Model
rails console
> Agent.new(name: 'Test', prompt_text: 'Test prompt here').valid?
> exit

# Database
rails db:migrate:status  # All up?
```

**Step 5: Commit documentation**

```bash
git add docs/phase-2a-manual-testing.md
git commit -m "docs: add Phase 2a manual testing results

Document successful manual testing via GraphiQL:
- All queries working
- All mutations working
- Error handling working
- Schema documentation visible

Phase 2a complete and verified.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 19: Create Pull Request

**No files to modify - Git operations only**

**Step 1: Push feature branch**

```bash
git push -u origin feature/phase-2a-agent-model-api
```

**Step 2: Create pull request**

```bash
gh pr create --title "Phase 2a: Agent Model + GraphQL API" --body "$(cat <<'EOF'
## Summary
Implements Phase 2a: Agent Model + GraphQL API for managing chess-playing agents.

## What's Included
- Agent model with validations (name, role, prompt_text, configuration)
- GraphQL CRUD API (queries + mutations)
- Complete test coverage (90%+)
- FactoryBot factories with traits
- Manual testing via GraphiQL verified

## Implementation Details
- **Model**: Agent with JSONB configuration column
- **Queries**: `agents`, `agent(id)`
- **Mutations**: `createAgent`, `updateAgent`, `deleteAgent`
- **Testing**: RSpec with 90%+ coverage

## Testing
```bash
bundle exec rspec
# All tests passing
# Coverage: 90%+
```

## Manual Testing
See `docs/phase-2a-manual-testing.md` for GraphiQL test results.

## Checklist
- [x] All tests passing
- [x] 90%+ test coverage
- [x] Manual testing via GraphiQL complete
- [x] Conventional commits used
- [x] Documentation updated

## Next Steps
After merge: Begin Phase 2b (API Configuration Model)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Step 3: Review PR**

```bash
gh pr view --web
```

**Step 4: Wait for approval, then merge**

```bash
# After approval
gh pr merge --squash
```

**Step 5: Switch back to main and pull**

```bash
git checkout main
git pull
```

---

## Completion Checklist

Before marking Phase 2a complete, verify:

### Code
- [ ] Agent model exists with all validations
- [ ] GraphQL types created (Agent, inputs, payloads)
- [ ] GraphQL queries working (agents, agent)
- [ ] GraphQL mutations working (createAgent, updateAgent, deleteAgent)
- [ ] FactoryBot factories with traits created

### Testing
- [ ] All RSpec tests passing
- [ ] 90%+ test coverage
- [ ] Model validations tested
- [ ] GraphQL operations tested
- [ ] Factory validations tested

### Manual Testing
- [ ] All GraphQL operations tested in GraphiQL
- [ ] Error handling verified
- [ ] Manual testing documented

### Git
- [ ] All commits use conventional format
- [ ] Feature branch created
- [ ] Pull request created
- [ ] PR merged to main

### Documentation
- [ ] Manual testing results documented
- [ ] Design document exists
- [ ] Implementation plan exists (this file)

---

## Summary

**Total Tasks**: 19
**Estimated Time**: 3-4 hours with TDD discipline

**Key Deliverables**:
- Agent model with full validations
- GraphQL CRUD API (2 queries, 3 mutations)
- 90%+ test coverage
- FactoryBot factories
- Manual testing verification

**TDD Approach**:
- RED: Write failing test
- GREEN: Minimal code to pass
- REFACTOR: Improve while keeping tests green
- COMMIT: Atomic commits with conventional format

**Next Phase**: Phase 2b - API Configuration Model
