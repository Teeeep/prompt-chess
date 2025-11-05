# Phase 3a: Match & Move Models + GraphQL - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create Match and Move models with full analytics schema, GraphQL types, and basic CRUD queries.

**Architecture:** Standard Rails models with enums, associations, validations. GraphQL types mirror ActiveRecord models. FactoryBot for test data.

**Tech Stack:** Rails 8, PostgreSQL, GraphQL-Ruby, RSpec, FactoryBot

**Dependencies:** None - this is the foundation layer

---

## Task 1: Match Model (TDD)

**Files:**
- Create: `spec/models/match_spec.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_create_matches.rb`
- Create: `app/models/match.rb`

**Step 1: Write the failing test**

Create `spec/models/match_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'associations' do
    it { should belong_to(:agent) }
    it { should have_many(:moves).dependent(:destroy).order(move_number: :asc) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:stockfish_level).in_range(1..8) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, errored: 3) }
    it { should define_enum_for(:winner).with_values(agent: 0, stockfish: 1, draw: 2) }
  end

  describe 'defaults' do
    let(:agent) { create(:agent) }
    let(:match) { Match.create!(agent: agent, stockfish_level: 5) }

    it 'sets total_moves to 0' do
      expect(match.total_moves).to eq(0)
    end

    it 'sets total_tokens_used to 0' do
      expect(match.total_tokens_used).to eq(0)
    end

    it 'sets total_cost_cents to 0' do
      expect(match.total_cost_cents).to eq(0)
    end

    it 'sets status to pending' do
      expect(match.status).to eq('pending')
    end
  end

  describe 'stockfish_level validation' do
    let(:agent) { create(:agent) }

    it 'allows levels 1-8' do
      (1..8).each do |level|
        match = Match.new(agent: agent, stockfish_level: level)
        expect(match).to be_valid
      end
    end

    it 'rejects level 0' do
      match = Match.new(agent: agent, stockfish_level: 0)
      expect(match).not_to be_valid
      expect(match.errors[:stockfish_level]).to be_present
    end

    it 'rejects level 9' do
      match = Match.new(agent: agent, stockfish_level: 9)
      expect(match).not_to be_valid
      expect(match.errors[:stockfish_level]).to be_present
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/match_spec.rb`
Expected: FAIL - "uninitialized constant Match"

**Step 3: Generate migration**

Run:
```bash
rails generate migration CreateMatches \
  agent:references \
  stockfish_level:integer \
  status:integer \
  winner:integer \
  result_reason:string \
  started_at:datetime \
  completed_at:datetime \
  total_moves:integer \
  opening_name:string \
  total_tokens_used:integer \
  total_cost_cents:integer \
  average_move_time_ms:integer \
  final_board_state:text \
  error_message:text
```

Edit the generated migration to add defaults, indexes, and null constraints:

```ruby
class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :agent, null: false, foreign_key: true, index: true
      t.integer :stockfish_level, null: false
      t.integer :status, null: false, default: 0
      t.integer :winner
      t.string :result_reason
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_moves, null: false, default: 0
      t.string :opening_name
      t.integer :total_tokens_used, null: false, default: 0
      t.integer :total_cost_cents, null: false, default: 0
      t.integer :average_move_time_ms
      t.text :final_board_state
      t.text :error_message

      t.timestamps
    end

    add_index :matches, :status
    add_index :matches, :created_at
  end
end
```

Run: `bundle exec rails db:migrate`

**Step 4: Create Match model**

Create `app/models/match.rb`:

```ruby
class Match < ApplicationRecord
  belongs_to :agent
  has_many :moves, -> { order(:move_number) }, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, errored: 3 }, prefix: true
  enum :winner, { agent: 0, stockfish: 1, draw: 2 }, prefix: true

  validates :stockfish_level, inclusion: { in: 1..8 }
  validates :status, presence: true
  validates :total_moves, numericality: { greater_than_or_equal_to: 0 }
  validates :total_tokens_used, numericality: { greater_than_or_equal_to: 0 }
  validates :total_cost_cents, numericality: { greater_than_or_equal_to: 0 }
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/models/match_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/models/match_spec.rb db/migrate/ app/models/match.rb db/schema.rb
git commit -m "feat(phase-3a): add Match model with full analytics schema

Create Match model with:
- Association to Agent
- Status enum (pending/in_progress/completed/errored)
- Winner enum (agent/stockfish/draw)
- Full analytics fields (tokens, cost, timing, opening)
- Validation for stockfish_level (1-8)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Move Model (TDD)

**Files:**
- Create: `spec/models/move_spec.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_create_moves.rb`
- Create: `app/models/move.rb`

**Step 1: Write the failing test**

Create `spec/models/move_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Move, type: :model do
  describe 'associations' do
    it { should belong_to(:match) }
  end

  describe 'validations' do
    it { should validate_presence_of(:move_number) }
    it { should validate_numericality_of(:move_number).is_greater_than(0) }
    it { should validate_presence_of(:move_notation) }
    it { should validate_presence_of(:board_state_after) }
    it { should validate_presence_of(:response_time_ms) }
  end

  describe 'enums' do
    it { should define_enum_for(:player).with_values(agent: 0, stockfish: 1) }
  end

  describe 'ordering' do
    let(:match) { create(:match) }
    let!(:move3) { create(:move, match: match, move_number: 3) }
    let!(:move1) { create(:move, match: match, move_number: 1) }
    let!(:move2) { create(:move, match: match, move_number: 2) }

    it 'orders moves by move_number through association' do
      expect(match.moves.pluck(:move_number)).to eq([1, 2, 3])
    end
  end

  describe 'uniqueness' do
    let(:match) { create(:match) }
    let!(:existing_move) { create(:move, match: match, move_number: 1) }

    it 'prevents duplicate move_number for same match' do
      duplicate_move = Move.new(
        match: match,
        move_number: 1,
        player: :stockfish,
        move_notation: 'e5',
        board_state_before: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        board_state_after: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        response_time_ms: 100
      )

      expect(duplicate_move).not_to be_valid
      expect(duplicate_move.errors[:move_number]).to include('has already been taken')
    end
  end

  describe 'agent-specific fields' do
    let(:match) { create(:match) }

    it 'allows llm_prompt for agent moves' do
      move = create(:move, match: match, player: :agent, llm_prompt: 'Test prompt')
      expect(move.llm_prompt).to eq('Test prompt')
    end

    it 'allows llm_response for agent moves' do
      move = create(:move, match: match, player: :agent, llm_response: 'Test response')
      expect(move.llm_response).to eq('Test response')
    end

    it 'allows tokens_used for agent moves' do
      move = create(:move, match: match, player: :agent, tokens_used: 150)
      expect(move.tokens_used).to eq(150)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/move_spec.rb`
Expected: FAIL - "uninitialized constant Move"

**Step 3: Generate migration**

Run:
```bash
rails generate migration CreateMoves \
  match:references \
  move_number:integer \
  player:integer \
  move_notation:string \
  board_state_before:text \
  board_state_after:text \
  llm_prompt:text \
  llm_response:text \
  tokens_used:integer \
  response_time_ms:integer
```

Edit the generated migration:

```ruby
class CreateMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :moves do |t|
      t.references :match, null: false, foreign_key: true
      t.integer :move_number, null: false
      t.integer :player, null: false
      t.string :move_notation, null: false
      t.text :board_state_before, null: false
      t.text :board_state_after, null: false
      t.text :llm_prompt
      t.text :llm_response
      t.integer :tokens_used
      t.integer :response_time_ms, null: false

      t.timestamps
    end

    add_index :moves, [:match_id, :move_number], unique: true
    add_index :moves, [:match_id, :player]
  end
end
```

Run: `bundle exec rails db:migrate`

**Step 4: Create Move model**

Create `app/models/move.rb`:

```ruby
class Move < ApplicationRecord
  belongs_to :match

  enum :player, { agent: 0, stockfish: 1 }, prefix: true

  validates :move_number, presence: true,
                          numericality: { greater_than: 0 },
                          uniqueness: { scope: :match_id }
  validates :move_notation, presence: true
  validates :board_state_before, presence: true
  validates :board_state_after, presence: true
  validates :response_time_ms, presence: true,
                                numericality: { greater_than_or_equal_to: 0 }
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/models/move_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/models/move_spec.rb db/migrate/ app/models/move.rb db/schema.rb
git commit -m "feat(phase-3a): add Move model with LLM interaction data

Create Move model with:
- Association to Match
- Player enum (agent/stockfish)
- Board states (before/after in FEN notation)
- LLM interaction fields (prompt, response, tokens)
- Response time tracking
- Unique constraint on (match_id, move_number)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: FactoryBot Factories

**Files:**
- Create: `spec/factories/matches.rb`
- Create: `spec/factories/moves.rb`

**Step 1: Create Match factory**

Create `spec/factories/matches.rb`:

```ruby
FactoryBot.define do
  factory :match do
    agent
    stockfish_level { 5 }
    status { :pending }
    total_moves { 0 }
    total_tokens_used { 0 }
    total_cost_cents { 0 }

    trait :in_progress do
      status { :in_progress }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      winner { :agent }
      result_reason { 'checkmate' }
      total_moves { 42 }
      total_tokens_used { 3500 }
      total_cost_cents { 5 }
      average_move_time_ms { 850 }
      opening_name { 'Sicilian Defense' }
      final_board_state { 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3' }
    end

    trait :errored do
      status { :errored }
      error_message { 'Test error message' }
    end

    trait :agent_won do
      completed
      winner { :agent }
    end

    trait :stockfish_won do
      completed
      winner { :stockfish }
    end

    trait :draw do
      completed
      winner { :draw }
      result_reason { 'stalemate' }
    end
  end
end
```

**Step 2: Create Move factory**

Create `spec/factories/moves.rb`:

```ruby
FactoryBot.define do
  factory :move do
    match
    move_number { 1 }
    player { :agent }
    move_notation { 'e4' }
    board_state_before { 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' }
    board_state_after { 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1' }
    response_time_ms { 500 }

    trait :agent_move do
      player { :agent }
      llm_prompt { 'You are playing chess. Current position: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1. Your move:' }
      llm_response { 'I will play e4. MOVE: e4' }
      tokens_used { 150 }
    end

    trait :stockfish_move do
      player { :stockfish }
      move_notation { 'e5' }
      board_state_before { 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1' }
      board_state_after { 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2' }
      response_time_ms { 50 }
      llm_prompt { nil }
      llm_response { nil }
      tokens_used { nil }
    end

    sequence(:move_number) { |n| n }
  end
end
```

**Step 3: Test factories work**

Run: `bundle exec rails console`

```ruby
match = FactoryBot.create(:match, :completed)
move = FactoryBot.create(:move, :agent_move, match: match)
puts "Match: #{match.status}, Winner: #{match.winner}"
puts "Move: #{move.move_notation} by #{move.player}"
```

Expected: No errors, objects created successfully

**Step 4: Commit**

```bash
git add spec/factories/
git commit -m "test(phase-3a): add FactoryBot factories for Match and Move

Create comprehensive factories with traits for:
- Match states: pending, in_progress, completed, errored
- Match outcomes: agent_won, stockfish_won, draw
- Move types: agent_move (with LLM data), stockfish_move

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: GraphQL Enums

**Files:**
- Create: `app/graphql/types/match_status_enum.rb`
- Create: `app/graphql/types/match_winner_enum.rb`
- Create: `app/graphql/types/move_player_enum.rb`

**Step 1: Create MatchStatusEnum**

Create `app/graphql/types/match_status_enum.rb`:

```ruby
module Types
  class MatchStatusEnum < Types::BaseEnum
    description "Status of a chess match"

    value "PENDING", "Match created but not started", value: "pending"
    value "IN_PROGRESS", "Match currently being played", value: "in_progress"
    value "COMPLETED", "Match finished", value: "completed"
    value "ERRORED", "Match encountered an error", value: "errored"
  end
end
```

**Step 2: Create MatchWinnerEnum**

Create `app/graphql/types/match_winner_enum.rb`:

```ruby
module Types
  class MatchWinnerEnum < Types::BaseEnum
    description "Winner of a chess match"

    value "AGENT", "Agent won", value: "agent"
    value "STOCKFISH", "Stockfish won", value: "stockfish"
    value "DRAW", "Game was a draw", value: "draw"
  end
end
```

**Step 3: Create MovePlayerEnum**

Create `app/graphql/types/move_player_enum.rb`:

```ruby
module Types
  class MovePlayerEnum < Types::BaseEnum
    description "Which player made a move"

    value "AGENT", "Agent's move", value: "agent"
    value "STOCKFISH", "Stockfish's move", value: "stockfish"
  end
end
```

**Step 4: Verify enums load**

Run: `bundle exec rails runner "puts Types::MatchStatusEnum.values.keys"`
Expected: `["PENDING", "IN_PROGRESS", "COMPLETED", "ERRORED"]`

**Step 5: Commit**

```bash
git add app/graphql/types/*_enum.rb
git commit -m "feat(phase-3a): add GraphQL enums for Match and Move

Create enums for:
- MatchStatus (pending, in_progress, completed, errored)
- MatchWinner (agent, stockfish, draw)
- MovePlayer (agent, stockfish)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: GraphQL Types (TDD)

**Files:**
- Create: `spec/requests/graphql/types/match_type_spec.rb`
- Create: `app/graphql/types/match_type.rb`
- Create: `app/graphql/types/move_type.rb`

**Step 1: Write failing test for MatchType**

Create `spec/requests/graphql/types/match_type_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Types::MatchType, type: :request do
  let(:match) { create(:match, :completed, :agent_won) }
  let(:query) do
    <<~GQL
      query($id: ID!) {
        match(id: $id) {
          id
          agent {
            id
            name
          }
          stockfishLevel
          status
          winner
          resultReason
          startedAt
          completedAt
          totalMoves
          openingName
          totalTokensUsed
          totalCostCents
          averageMoveTimeMs
          finalBoardState
          errorMessage
          createdAt
          updatedAt
        }
      }
    GQL
  end

  def execute_query(id:)
    post '/graphql', params: { query: query, variables: { id: id } }
    JSON.parse(response.body)
  end

  it 'returns all match fields' do
    result = execute_query(id: match.id)

    match_data = result.dig('data', 'match')
    expect(match_data['id']).to eq(match.id.to_s)
    expect(match_data['stockfishLevel']).to eq(5)
    expect(match_data['status']).to eq('COMPLETED')
    expect(match_data['winner']).to eq('AGENT')
    expect(match_data['resultReason']).to eq('checkmate')
    expect(match_data['totalMoves']).to eq(42)
    expect(match_data['openingName']).to eq('Sicilian Defense')
    expect(match_data['totalTokensUsed']).to eq(3500)
    expect(match_data['totalCostCents']).to eq(5)
    expect(match_data['averageMoveTimeMs']).to eq(850)
    expect(match_data['finalBoardState']).to be_present
  end

  it 'includes agent association' do
    result = execute_query(id: match.id)

    agent_data = result.dig('data', 'match', 'agent')
    expect(agent_data['id']).to eq(match.agent.id.to_s)
    expect(agent_data['name']).to eq(match.agent.name)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/types/match_type_spec.rb`
Expected: FAIL - query field not found

**Step 3: Create MatchType**

Create `app/graphql/types/match_type.rb`:

```ruby
module Types
  class MatchType < Types::BaseObject
    description "A chess match between an agent and Stockfish"

    field :id, ID, null: false
    field :agent, Types::AgentType, null: false
    field :stockfish_level, Integer, null: false,
      description: "Stockfish difficulty level (1-8)"

    field :status, Types::MatchStatusEnum, null: false
    field :winner, Types::MatchWinnerEnum, null: true
    field :result_reason, String, null: true,
      description: "How the game ended (checkmate, stalemate, etc.)"

    field :started_at, GraphQL::Types::ISO8601DateTime, null: true
    field :completed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :total_moves, Integer, null: false
    field :opening_name, String, null: true

    field :total_tokens_used, Integer, null: false
    field :total_cost_cents, Integer, null: false,
      description: "Estimated API cost in cents"
    field :average_move_time_ms, Integer, null: true,
      description: "Average time per move in milliseconds"
    field :final_board_state, String, null: true,
      description: "Final position in FEN notation"

    field :error_message, String, null: true

    field :moves, [Types::MoveType], null: false

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
```

**Step 4: Create MoveType**

Create `app/graphql/types/move_type.rb`:

```ruby
module Types
  class MoveType < Types::BaseObject
    description "A single move in a chess match"

    field :id, ID, null: false
    field :move_number, Integer, null: false,
      description: "Move number in the game (1-based)"
    field :player, Types::MovePlayerEnum, null: false
    field :move_notation, String, null: false,
      description: "Move in standard algebraic notation (e.g., e4, Nf3, O-O)"

    field :board_state_before, String, null: false,
      description: "Position before move in FEN notation"
    field :board_state_after, String, null: false,
      description: "Position after move in FEN notation"

    field :llm_prompt, String, null: true,
      description: "Full prompt sent to LLM (agent moves only)"
    field :llm_response, String, null: true,
      description: "Raw LLM response (agent moves only)"
    field :tokens_used, Integer, null: true,
      description: "Tokens consumed by this move (agent moves only)"

    field :response_time_ms, Integer, null: false,
      description: "Time taken to generate this move in milliseconds"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
```

**Step 5: Add match query to QueryType**

Modify `app/graphql/types/query_type.rb`:

Add these fields:

```ruby
field :match, Types::MatchType, null: true do
  description "Find a match by ID"
  argument :id, ID, required: true
end

def match(id:)
  Match.find_by(id: id)
end

field :matches, [Types::MatchType], null: false do
  description "List matches with optional filters"
  argument :agent_id, ID, required: false
  argument :status, Types::MatchStatusEnum, required: false
end

def matches(agent_id: nil, status: nil)
  scope = Match.includes(:agent).order(created_at: :desc)
  scope = scope.where(agent_id: agent_id) if agent_id
  scope = scope.where(status: status) if status
  scope
end
```

**Step 6: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/types/match_type_spec.rb`
Expected: All tests pass

**Step 7: Commit**

```bash
git add app/graphql/types/match_type.rb app/graphql/types/move_type.rb \
        app/graphql/types/query_type.rb spec/requests/graphql/types/
git commit -m "feat(phase-3a): add GraphQL types for Match and Move

Create comprehensive GraphQL types with:
- MatchType: all analytics fields, associations, timestamps
- MoveType: board states, LLM data, timing
- Queries: match(id), matches(agentId, status)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Integration Testing

**Files:**
- Create: `spec/requests/graphql/matches_spec.rb`

**Step 1: Write integration tests**

Create `spec/requests/graphql/matches_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Matches GraphQL API', type: :request do
  let(:agent) { create(:agent) }

  describe 'Query: match' do
    let(:match) { create(:match, agent: agent) }
    let!(:move1) { create(:move, :agent_move, match: match, move_number: 1) }
    let!(:move2) { create(:move, :stockfish_move, match: match, move_number: 2) }

    let(:query) do
      <<~GQL
        query($id: ID!) {
          match(id: $id) {
            id
            agent { id }
            stockfishLevel
            status
            totalMoves
            moves {
              id
              moveNumber
              player
              moveNotation
              llmPrompt
              llmResponse
              tokensUsed
            }
          }
        }
      GQL
    end

    it 'returns match with moves in order' do
      post '/graphql', params: { query: query, variables: { id: match.id } }
      result = JSON.parse(response.body)

      match_data = result.dig('data', 'match')
      expect(match_data['id']).to eq(match.id.to_s)
      expect(match_data['moves'].length).to eq(2)

      # Verify move order
      expect(match_data['moves'][0]['moveNumber']).to eq(1)
      expect(match_data['moves'][1]['moveNumber']).to eq(2)

      # Verify agent move has LLM data
      agent_move = match_data['moves'][0]
      expect(agent_move['player']).to eq('AGENT')
      expect(agent_move['llmPrompt']).to be_present
      expect(agent_move['llmResponse']).to be_present
      expect(agent_move['tokensUsed']).to be > 0

      # Verify stockfish move has no LLM data
      stockfish_move = match_data['moves'][1]
      expect(stockfish_move['player']).to eq('STOCKFISH')
      expect(stockfish_move['llmPrompt']).to be_nil
      expect(stockfish_move['llmResponse']).to be_nil
      expect(stockfish_move['tokensUsed']).to be_nil
    end

    it 'returns null for non-existent match' do
      post '/graphql', params: { query: query, variables: { id: 99999 } }
      result = JSON.parse(response.body)

      expect(result.dig('data', 'match')).to be_nil
    end
  end

  describe 'Query: matches' do
    let(:agent2) { create(:agent) }
    let!(:pending_match) { create(:match, agent: agent, status: :pending) }
    let!(:completed_match) { create(:match, :completed, agent: agent) }
    let!(:other_agent_match) { create(:match, agent: agent2) }

    let(:query) do
      <<~GQL
        query($agentId: ID, $status: MatchStatus) {
          matches(agentId: $agentId, status: $status) {
            id
            agent { id }
            status
          }
        }
      GQL
    end

    it 'returns all matches without filters' do
      post '/graphql', params: { query: query }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(3)
    end

    it 'filters by agent_id' do
      post '/graphql', params: { query: query, variables: { agentId: agent.id } }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(2)
      expect(matches.map { |m| m['agent']['id'] }.uniq).to eq([agent.id.to_s])
    end

    it 'filters by status' do
      post '/graphql', params: { query: query, variables: { status: 'COMPLETED' } }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(1)
      expect(matches[0]['status']).to eq('COMPLETED')
    end

    it 'filters by agent_id and status' do
      post '/graphql', params: {
        query: query,
        variables: { agentId: agent.id, status: 'PENDING' }
      }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      expect(matches.length).to eq(1)
      expect(matches[0]['id']).to eq(pending_match.id.to_s)
    end

    it 'orders matches by created_at descending' do
      post '/graphql', params: { query: query }
      result = JSON.parse(response.body)

      matches = result.dig('data', 'matches')
      ids = matches.map { |m| m['id'].to_i }

      # Newest match should be first
      expect(ids).to eq(ids.sort.reverse)
    end
  end
end
```

**Step 2: Run tests**

Run: `bundle exec rspec spec/requests/graphql/matches_spec.rb`
Expected: All tests pass

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass (including Phase 1, 2a, 2b, and 3a)

**Step 4: Commit**

```bash
git add spec/requests/graphql/matches_spec.rb
git commit -m "test(phase-3a): add integration tests for Match GraphQL API

Add comprehensive tests for:
- match query with moves (ordered, with LLM data)
- matches query with filtering (agentId, status)
- matches ordering (newest first)
- null handling for non-existent matches

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verification Checklist

Before marking Phase 3a complete:

- [ ] All tests pass (`bundle exec rspec`)
- [ ] Coverage ≥ 90% for new code
- [ ] Can create Match and Move records via factories
- [ ] Can query match(id) via GraphQL
- [ ] Can query matches with filters via GraphQL
- [ ] GraphQL returns moves in correct order
- [ ] Agent moves include LLM data, Stockfish moves don't
- [ ] Database indexes created (agent_id, status, created_at)
- [ ] All commits follow conventional format

---

## Dependencies for Next Phases

**Phase 3b (Stockfish) needs:**
- Match and Move models ✓
- Nothing else

**Phase 3c (Agent Move Generation) needs:**
- Match and Move models ✓
- Move factory ✓
- Nothing else (will use Phase 2b's AnthropicClient)

**Phase 3d (Match Orchestration) needs:**
- Match and Move models ✓
- All GraphQL types ✓
- Services from 3b and 3c

**Phase 3e (Real-time UI) needs:**
- Everything from 3d
- Match query ✓

---

**Phase 3a Status:** Ready for implementation
**Estimated Time:** 2-3 hours
**Complexity:** Low (standard Rails CRUD)
