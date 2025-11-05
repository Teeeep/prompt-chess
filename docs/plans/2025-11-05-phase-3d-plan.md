# Phase 3d: Match Orchestration - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create MatchRunner to orchestrate complete chess games, MatchExecutionJob for background execution, and createMatch mutation to start matches.

**Architecture:** MatchRunner coordinates game loop using AgentMoveService and StockfishService, saving moves to database. MatchExecutionJob wraps execution in background job. GraphQL mutation creates match and enqueues job.

**Tech Stack:** Rails 8, Solid Queue, GraphQL-Ruby, RSpec

**Dependencies:**
- Phase 3a complete (Match, Move models, GraphQL types)
- Phase 3b complete (StockfishService, MoveValidator)
- Phase 3c complete (AgentMoveService)

---

## Task 1: MatchRunner Service - Basic Structure (TDD)

**Files:**
- Create: `spec/services/match_runner_spec.rb`
- Create: `app/services/match_runner.rb`

**Step 1: Write the failing test**

Create `spec/services/match_runner_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MatchRunner do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1, status: :pending) }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  describe '#initialize' do
    it 'creates runner with match and session' do
      runner = MatchRunner.new(match: match, session: session)
      expect(runner).to be_a(MatchRunner)
    end

    it 'raises error without match' do
      expect {
        MatchRunner.new(match: nil, session: session)
      }.to raise_error(ArgumentError, /match is required/)
    end

    it 'raises error without session' do
      expect {
        MatchRunner.new(match: match, session: nil)
      }.to raise_error(ArgumentError, /session is required/)
    end

    it 'initializes validator with starting position' do
      runner = MatchRunner.new(match: match, session: session)
      expect(runner.instance_variable_get(:@validator).current_fen).to eq(Chess::Game::DEFAULT_FEN)
    end
  end

  describe '#run!', :vcr do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    context 'successful game completion' do
      it 'updates match status to in_progress', vcr: { cassette_name: 'match_runner/full_game' } do
        # Stub to play only 2 moves each
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.status).to eq('completed')
        expect(match.started_at).to be_present
        expect(match.completed_at).to be_present
      end

      it 'creates Move records for each move', vcr: { cassette_name: 'match_runner/move_creation' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        expect {
          runner.run!
        }.to change { match.moves.count }.by_at_least(4)

        # Check move sequence
        moves = match.moves.order(:move_number)
        expect(moves.first.player).to eq('agent')
        expect(moves.second.player).to eq('stockfish')
      end

      it 'alternates between agent and stockfish', vcr: { cassette_name: 'match_runner/alternation' } do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        moves = match.moves.order(:move_number)
        expect(moves[0].player).to eq('agent')
        expect(moves[1].player).to eq('stockfish')
        expect(moves[2].player).to eq('agent')
        expect(moves[3].player).to eq('stockfish')
      end

      it 'saves LLM data for agent moves', vcr: { cassette_name: 'match_runner/agent_move_data' } do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        agent_move = match.moves.agent.first
        expect(agent_move.llm_prompt).to be_present
        expect(agent_move.llm_response).to be_present
        expect(agent_move.tokens_used).to be > 0
      end

      it 'does not save LLM data for stockfish moves', vcr: { cassette_name: 'match_runner/stockfish_move_data' } do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        stockfish_move = match.moves.stockfish.first
        expect(stockfish_move.llm_prompt).to be_nil
        expect(stockfish_move.llm_response).to be_nil
        expect(stockfish_move.tokens_used).to be_nil
      end

      it 'updates match total_moves counter' do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.total_moves).to eq(4)
      end

      it 'accumulates total_tokens_used' do
        allow(runner).to receive(:game_over?).and_return(false, false, false, false, true)

        runner.run!

        match.reload
        expect(match.total_tokens_used).to be > 0
      end
    end

    context 'game ending conditions' do
      it 'detects checkmate and sets winner', vcr: { cassette_name: 'match_runner/checkmate' } do
        # Fool's Mate position (fastest checkmate)
        allow(runner).to receive(:play_turn).and_wrap_original do |method, *args|
          method.call(*args)
          # After 4 moves, should be checkmate
          runner.instance_variable_get(:@validator).apply_move('f3') if match.moves.count == 0
          runner.instance_variable_get(:@validator).apply_move('e5') if match.moves.count == 1
          runner.instance_variable_get(:@validator).apply_move('g4') if match.moves.count == 2
          runner.instance_variable_get(:@validator).apply_move('Qh4') if match.moves.count == 3
        end

        runner.run!

        match.reload
        expect(match.status).to eq('completed')
        expect(match.result_reason).to eq('checkmate')
        expect(match.winner).to be_present
      end

      it 'sets final_board_state on completion' do
        allow(runner).to receive(:game_over?).and_return(false, false, true)

        runner.run!

        match.reload
        expect(match.final_board_state).to be_present
        expect(match.final_board_state).to match(/^[rnbqkpRNBQKP1-8\/]+/) # FEN format
      end
    end
  end

  describe '#play_turn' do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    it 'calls AgentMoveService for agent turn', vcr: { cassette_name: 'match_runner/agent_turn' } do
      expect_any_instance_of(AgentMoveService).to receive(:generate_move).and_call_original

      runner.send(:play_turn, player: :agent)
    end

    it 'calls StockfishService for stockfish turn' do
      expect_any_instance_of(StockfishService).to receive(:get_move).and_call_original

      runner.send(:play_turn, player: :stockfish)
    end

    it 'creates Move record with correct player' do
      expect {
        runner.send(:play_turn, player: :agent)
      }.to change { match.moves.agent.count }.by(1)
    end

    it 'stores board states before and after move' do
      runner.send(:play_turn, player: :agent)

      move = match.moves.last
      expect(move.board_state_before).to eq(Chess::Game::DEFAULT_FEN)
      expect(move.board_state_after).not_to eq(Chess::Game::DEFAULT_FEN)
    end
  end

  describe 'error handling' do
    let(:runner) { MatchRunner.new(match: match, session: session) }

    context 'when agent fails to produce valid move' do
      it 'marks match as errored' do
        allow_any_instance_of(AgentMoveService).to receive(:generate_move).and_raise(
          AgentMoveService::InvalidMoveError, 'Failed after 3 attempts'
        )

        expect {
          runner.run!
        }.to raise_error(AgentMoveService::InvalidMoveError)

        match.reload
        expect(match.status).to eq('errored')
        expect(match.error_message).to include('Failed after 3 attempts')
      end
    end

    context 'when Stockfish crashes' do
      it 'marks match as errored' do
        allow_any_instance_of(StockfishService).to receive(:get_move).and_raise(
          StockfishService::StockfishError, 'Process died'
        )

        expect {
          runner.run!
        }.to raise_error(StockfishService::StockfishError)

        match.reload
        expect(match.status).to eq('errored')
        expect(match.error_message).to include('Process died')
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/match_runner_spec.rb`
Expected: FAIL - "uninitialized constant MatchRunner"

**Step 3: Create MatchRunner service**

Create `app/services/match_runner.rb`:

```ruby
class MatchRunner
  attr_reader :match

  def initialize(match:, session:)
    raise ArgumentError, "match is required" unless match
    raise ArgumentError, "session is required" unless session

    @match = match
    @session = session
    @validator = MoveValidator.new
    @stockfish = StockfishService.new(level: @match.stockfish_level)
  end

  def run!
    @match.update!(status: :in_progress, started_at: Time.current)

    begin
      current_player = :agent # Agent plays white, goes first

      until game_over?
        play_turn(player: current_player)

        # Alternate players
        current_player = current_player == :agent ? :stockfish : :agent
      end

      finalize_match
    rescue StandardError => e
      @match.update!(
        status: :errored,
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    ensure
      @stockfish&.close
    end
  end

  private

  def play_turn(player:)
    board_before = @validator.current_fen
    move_number = (@match.moves.count / 2) + 1

    if player == :agent
      play_agent_move(board_before, move_number)
    else
      play_stockfish_move(board_before, move_number)
    end
  end

  def play_agent_move(board_before, move_number)
    # Build move history for context
    move_history = @match.moves.order(:move_number).to_a

    # Generate move
    agent_service = AgentMoveService.new(
      agent: @match.agent,
      validator: @validator,
      move_history: move_history,
      session: @session
    )

    result = agent_service.generate_move

    # Apply move to validator
    board_after = @validator.apply_move(result[:move])

    # Create move record
    @match.moves.create!(
      move_number: move_number,
      player: :agent,
      move_notation: result[:move],
      board_state_before: board_before,
      board_state_after: board_after,
      llm_prompt: result[:prompt],
      llm_response: result[:response],
      tokens_used: result[:tokens],
      response_time_ms: result[:time_ms]
    )

    # Update match totals
    @match.increment!(:total_tokens_used, result[:tokens])
    @match.increment!(:total_moves)
  end

  def play_stockfish_move(board_before, move_number)
    result = @stockfish.get_move(board_before)

    # Apply move to validator
    board_after = @validator.apply_move(result[:move])

    # Create move record
    @match.moves.create!(
      move_number: move_number,
      player: :stockfish,
      move_notation: result[:move],
      board_state_before: board_before,
      board_state_after: board_after,
      response_time_ms: result[:time_ms]
    )

    @match.increment!(:total_moves)
  end

  def game_over?
    @validator.game_over?
  end

  def finalize_match
    result = @validator.result
    winner = determine_winner(result)

    # Calculate average move time
    agent_moves = @match.moves.agent
    avg_time = agent_moves.any? ? agent_moves.average(:response_time_ms).to_i : nil

    @match.update!(
      status: :completed,
      completed_at: Time.current,
      winner: winner,
      result_reason: result,
      final_board_state: @validator.current_fen,
      average_move_time_ms: avg_time
    )
  end

  def determine_winner(result)
    case result
    when 'checkmate'
      # Last move wins - check who moved last
      last_move = @match.moves.order(:move_number).last
      last_move.player == 'agent' ? :agent : :stockfish
    when 'stalemate'
      :draw
    else
      :draw
    end
  end
end
```

**Step 4: Add enum scopes to Move model**

Modify `app/models/move.rb`:

```ruby
class Move < ApplicationRecord
  belongs_to :match

  enum :player, { agent: 0, stockfish: 1 }, prefix: true, scopes: true

  # ... existing validations ...
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/services/match_runner_spec.rb --tag ~vcr`
Expected: Structure tests pass (VCR tests need cassettes)

**Step 6: Commit**

```bash
git add spec/services/match_runner_spec.rb app/services/match_runner.rb app/models/move.rb
git commit -m "feat(phase-3d): add MatchRunner service for game orchestration

Create MatchRunner to:
- Orchestrate complete chess games from start to finish
- Alternate between agent and Stockfish moves
- Create Move records with full context (board states, LLM data)
- Update Match with progress (total_moves, total_tokens_used)
- Detect game over conditions (checkmate, stalemate)
- Finalize match with winner and statistics
- Handle errors gracefully (agent failures, engine crashes)

Add scopes to Move model:
- agent scope for filtering agent moves
- stockfish scope for filtering stockfish moves

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Record VCR Cassettes for MatchRunner

**Files:**
- Create: VCR cassettes in `spec/vcr_cassettes/match_runner/`

**Step 1: Record cassettes for various scenarios**

Run:
```bash
export ANTHROPIC_API_KEY="your-real-api-key"
bundle exec rspec spec/services/match_runner_spec.rb --tag vcr
```

Expected: Multiple cassettes recorded

**Step 2: Verify tests pass without API key**

Run:
```bash
unset ANTHROPIC_API_KEY
bundle exec rspec spec/services/match_runner_spec.rb
```

Expected: All tests pass using cassettes

**Step 3: Commit**

```bash
git add spec/vcr_cassettes/match_runner/
git commit -m "test(phase-3d): add VCR cassettes for MatchRunner

Record LLM interactions for:
- Full game execution
- Move creation and alternation
- Agent and Stockfish move data
- Game ending conditions

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: MatchExecutionJob (TDD)

**Files:**
- Create: `spec/jobs/match_execution_job_spec.rb`
- Create: `app/jobs/match_execution_job.rb`

**Step 1: Write the failing test**

Create `spec/jobs/match_execution_job_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MatchExecutionJob, type: :job do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  describe '#perform' do
    it 'executes the match runner', vcr: { cassette_name: 'match_execution_job/success' } do
      # Stub to play short game
      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(false, false, true)

      MatchExecutionJob.perform_now(match.id, session)

      match.reload
      expect(match.status).to eq('completed')
      expect(match.moves.count).to be > 0
    end

    it 'marks match as errored on failure' do
      allow_any_instance_of(MatchRunner).to receive(:run!).and_raise(
        StandardError, 'Test error'
      )

      expect {
        MatchExecutionJob.perform_now(match.id, session)
      }.to raise_error(StandardError, 'Test error')

      match.reload
      expect(match.status).to eq('errored')
      expect(match.error_message).to include('Test error')
    end

    it 'finds match by ID' do
      expect(Match).to receive(:find).with(match.id).and_call_original

      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(true)

      MatchExecutionJob.perform_now(match.id, session)
    end

    it 'passes session to MatchRunner' do
      expect(MatchRunner).to receive(:new).with(
        match: match,
        session: session
      ).and_call_original

      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(true)

      MatchExecutionJob.perform_now(match.id, session)
    end
  end

  describe 'job configuration' do
    it 'is enqueued on default queue' do
      expect(MatchExecutionJob.new.queue_name).to eq('default')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/match_execution_job_spec.rb`
Expected: FAIL - "uninitialized constant MatchExecutionJob"

**Step 3: Generate job**

Run: `rails generate job MatchExecution`

**Step 4: Implement job**

Modify `app/jobs/match_execution_job.rb`:

```ruby
class MatchExecutionJob < ApplicationJob
  queue_as :default

  def perform(match_id, session)
    match = Match.find(match_id)

    # Run the match
    runner = MatchRunner.new(match: match, session: session)
    runner.run!
  rescue StandardError => e
    # Match error state is already set by MatchRunner
    # Re-raise for job retry logic
    raise
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/jobs/match_execution_job_spec.rb --tag ~vcr`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/jobs/match_execution_job_spec.rb app/jobs/match_execution_job.rb
git commit -m "feat(phase-3d): add MatchExecutionJob for background processing

Create background job to:
- Execute matches asynchronously via Solid Queue
- Find match by ID and pass session context
- Run MatchRunner.run!
- Re-raise errors for retry logic

Job configuration:
- Default queue
- Standard retry behavior (3 attempts)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: CreateMatch Mutation (TDD)

**Files:**
- Create: `spec/requests/graphql/mutations/create_match_spec.rb`
- Create: `app/graphql/mutations/create_match.rb`
- Modify: `app/graphql/types/mutation_type.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/mutations/create_match_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Mutations::CreateMatch', type: :request do
  let(:agent) { create(:agent) }
  let(:session_data) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  let(:mutation) do
    <<~GQL
      mutation($agentId: ID!, $stockfishLevel: Int!) {
        createMatch(agentId: $agentId, stockfishLevel: $stockfishLevel) {
          match {
            id
            agent { id }
            stockfishLevel
            status
          }
          errors
        }
      }
    GQL
  end

  def execute_mutation(agent_id:, stockfish_level:, session: {})
    post '/graphql', params: {
      query: mutation,
      variables: { agentId: agent_id, stockfishLevel: stockfish_level }
    }, session: session

    JSON.parse(response.body)
  end

  describe 'successful creation' do
    it 'creates a match' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 5, session: session_data)
      }.to change { Match.count }.by(1)

      result = JSON.parse(response.body)
      match_data = result.dig('data', 'createMatch', 'match')

      expect(match_data['agentId']).to eq(agent.id.to_s)
      expect(match_data['stockfishLevel']).to eq(5)
      expect(match_data['status']).to eq('PENDING')
    end

    it 'enqueues MatchExecutionJob' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 3, session: session_data)
      }.to have_enqueued_job(MatchExecutionJob)
    end

    it 'passes session to job' do
      execute_mutation(agent_id: agent.id, stockfish_level: 5, session: session_data)

      expect(MatchExecutionJob).to have_been_enqueued.with { |match_id, session|
        expect(match_id).to be_a(Integer)
        expect(session).to eq(session_data)
      }
    end

    it 'returns no errors' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 5, session: session_data)
      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to be_empty
    end
  end

  describe 'validation errors' do
    it 'returns error for non-existent agent' do
      result = execute_mutation(agent_id: 99999, stockfish_level: 5, session: session_data)

      match_data = result.dig('data', 'createMatch', 'match')
      errors = result.dig('data', 'createMatch', 'errors')

      expect(match_data).to be_nil
      expect(errors).to include('Agent not found')
    end

    it 'returns error for invalid stockfish level (too low)' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 0, session: session_data)

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Stockfish level must be between 1 and 8')
    end

    it 'returns error for invalid stockfish level (too high)' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 9, session: session_data)

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Stockfish level must be between 1 and 8')
    end

    it 'returns error when LLM not configured' do
      result = execute_mutation(agent_id: agent.id, stockfish_level: 5, session: {})

      errors = result.dig('data', 'createMatch', 'errors')
      expect(errors).to include('Please configure your API credentials first')
    end

    it 'does not create match when validation fails' do
      expect {
        execute_mutation(agent_id: 99999, stockfish_level: 5, session: session_data)
      }.not_to change { Match.count }
    end

    it 'does not enqueue job when validation fails' do
      expect {
        execute_mutation(agent_id: agent.id, stockfish_level: 0, session: session_data)
      }.not_to have_enqueued_job(MatchExecutionJob)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/mutations/create_match_spec.rb`
Expected: FAIL - mutation not found

**Step 3: Create CreateMatch mutation**

Create `app/graphql/mutations/create_match.rb`:

```ruby
module Mutations
  class CreateMatch < BaseMutation
    description "Create a new match between an agent and Stockfish"

    argument :agent_id, ID, required: true,
      description: "ID of the agent to play"
    argument :stockfish_level, Integer, required: true,
      description: "Stockfish difficulty level (1-8)"

    field :match, Types::MatchType, null: true
    field :errors, [String], null: false

    def resolve(agent_id:, stockfish_level:)
      agent = Agent.find_by(id: agent_id)
      errors = []

      unless agent
        errors << "Agent not found"
      end

      unless (1..8).include?(stockfish_level)
        errors << "Stockfish level must be between 1 and 8"
      end

      # Check if LLM is configured in session
      unless LlmConfigService.configured?(context[:session])
        errors << "Please configure your API credentials first"
      end

      return { match: nil, errors: errors } if errors.any?

      # Create match
      match = Match.create!(
        agent: agent,
        stockfish_level: stockfish_level,
        status: :pending
      )

      # Enqueue background job with session context
      MatchExecutionJob.perform_later(match.id, context[:session])

      { match: match, errors: [] }
    end
  end
end
```

**Step 4: Register mutation in MutationType**

Modify `app/graphql/types/mutation_type.rb`:

Add:
```ruby
field :create_match, mutation: Mutations::CreateMatch
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/graphql/mutations/create_match_spec.rb`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/requests/graphql/mutations/create_match_spec.rb \
        app/graphql/mutations/create_match.rb \
        app/graphql/types/mutation_type.rb
git commit -m "feat(phase-3d): add createMatch GraphQL mutation

Create mutation to:
- Accept agentId and stockfishLevel parameters
- Validate agent exists
- Validate stockfish level (1-8)
- Check LLM configuration in session
- Create Match record with pending status
- Enqueue MatchExecutionJob with session context
- Return match or validation errors

Includes comprehensive tests for:
- Successful match creation
- Job enqueueing with session
- Validation errors (missing agent, invalid level, no LLM config)
- Error handling (no match created on validation failure)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Integration Test - Full Flow

**Files:**
- Create: `spec/integration/match_execution_flow_spec.rb`

**Step 1: Write integration test**

Create `spec/integration/match_execution_flow_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Match Execution Flow', type: :integration do
  let(:agent) { create(:agent, name: 'Test Agent', prompt: 'You play aggressively.') }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  describe 'complete match lifecycle', :vcr do
    it 'creates and executes match end-to-end', vcr: { cassette_name: 'integration/full_match_flow' } do
      # 1. Create match via GraphQL
      mutation = <<~GQL
        mutation($agentId: ID!, $stockfishLevel: Int!) {
          createMatch(agentId: $agentId, stockfishLevel: $stockfishLevel) {
            match {
              id
              status
            }
            errors
          }
        }
      GQL

      post '/graphql', params: {
        query: mutation,
        variables: { agentId: agent.id, stockfishLevel: 1 }
      }, session: session

      result = JSON.parse(response.body)
      match_id = result.dig('data', 'createMatch', 'match', 'id')
      expect(match_id).to be_present

      # 2. Execute job (normally async, but inline for test)
      match = Match.find(match_id)

      # Stub to play short game
      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(
        false, false, false, false, true
      )

      perform_enqueued_jobs do
        MatchExecutionJob.perform_later(match.id, session)
      end

      # 3. Verify match completed
      match.reload
      expect(match.status).to eq('completed')
      expect(match.moves.count).to eq(4)
      expect(match.winner).to be_present
      expect(match.result_reason).to be_present

      # 4. Verify moves created correctly
      moves = match.moves.order(:move_number)
      expect(moves.first.player).to eq('agent')
      expect(moves.second.player).to eq('stockfish')

      # 5. Verify LLM data captured
      agent_move = moves.agent.first
      expect(agent_move.llm_prompt).to include('Test Agent')
      expect(agent_move.llm_prompt).to include('You play aggressively')
      expect(agent_move.llm_response).to be_present
      expect(agent_move.tokens_used).to be > 0

      # 6. Query match via GraphQL
      query = <<~GQL
        query($id: ID!) {
          match(id: $id) {
            id
            status
            winner
            totalMoves
            moves {
              moveNumber
              player
              moveNotation
            }
          }
        }
      GQL

      post '/graphql', params: {
        query: query,
        variables: { id: match.id }
      }

      query_result = JSON.parse(response.body)
      match_data = query_result.dig('data', 'match')

      expect(match_data['status']).to eq('COMPLETED')
      expect(match_data['totalMoves']).to eq(4)
      expect(match_data['moves'].length).to eq(4)
    end
  end
end
```

**Step 2: Configure RSpec for job testing**

Ensure `spec/rails_helper.rb` has:

```ruby
RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.around(:each, type: :integration) do |example|
    ActiveJob::Base.queue_adapter = :test
    example.run
    ActiveJob::Base.queue_adapter = :async
  end
end
```

**Step 3: Run integration test**

Run: `bundle exec rspec spec/integration/match_execution_flow_spec.rb --tag ~vcr`
Expected: Test structure passes

**Step 4: Record VCR cassette**

Run:
```bash
export ANTHROPIC_API_KEY="your-real-api-key"
bundle exec rspec spec/integration/match_execution_flow_spec.rb
```

Expected: Full integration test passes with recorded cassette

**Step 5: Run all tests**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/integration/match_execution_flow_spec.rb spec/rails_helper.rb
git commit -m "test(phase-3d): add end-to-end integration test

Add integration test covering full match lifecycle:
1. Create match via GraphQL mutation
2. Execute MatchExecutionJob
3. Verify match completion with correct status
4. Verify moves created (agent and stockfish alternating)
5. Verify LLM data captured for agent moves
6. Query match via GraphQL to confirm data accessible

Configure RSpec:
- ActiveJob::TestHelper for job testing
- Test queue adapter for integration tests

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verification Checklist

Before marking Phase 3d complete:

- [ ] MatchRunner service created and tested
- [ ] MatchExecutionJob created and tested
- [ ] CreateMatch mutation created and tested
- [ ] Full integration test passes (end-to-end flow)
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Coverage ≥ 90% for Phase 3d code
- [ ] VCR cassettes recorded for all LLM interactions
- [ ] Jobs enqueue correctly with session context
- [ ] Error handling works (agent failures, engine crashes)
- [ ] Match statistics calculated correctly (tokens, moves, timing)

---

## Dependencies for Next Phase

**Phase 3e (Real-time UI) needs:**
- Everything from 3d ✓
- CreateMatch mutation ✓
- Match and Move GraphQL types (from 3a) ✓

---

**Phase 3d Status:** Ready for implementation
**Estimated Time:** 3-4 hours
**Complexity:** High (orchestration, background jobs, error handling, integration testing)
