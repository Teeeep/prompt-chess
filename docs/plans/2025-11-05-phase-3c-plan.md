# Phase 3c: Agent Move Generation - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create AgentMoveService to generate chess moves by calling LLM with full game context, parsing responses, and handling errors.

**Architecture:** AgentMoveService builds context-rich prompts, calls AnthropicClient (from Phase 2b), parses move from response, validates with MoveValidator, retries on failure.

**Tech Stack:** Rails 8, RSpec, VCR for LLM mocking

**Dependencies:**
- Phase 2b complete (AnthropicClient, LlmConfigService)
- Phase 3a complete (Match, Move models)
- Phase 3b complete (MoveValidator)

---

## Task 1: AgentMoveService Basic Structure (TDD)

**Files:**
- Create: `spec/services/agent_move_service_spec.rb`
- Create: `app/services/agent_move_service.rb`

**Step 1: Write the failing test**

Create `spec/services/agent_move_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe AgentMoveService do
  let(:agent) { create(:agent, prompt: 'You are a tactical chess master.') }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }
  let(:validator) { MoveValidator.new }

  describe '#initialize' do
    it 'creates service with required parameters' do
      service = AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )

      expect(service).to be_a(AgentMoveService)
    end

    it 'raises error without agent' do
      expect {
        AgentMoveService.new(
          agent: nil,
          validator: validator,
          move_history: [],
          session: session
        )
      }.to raise_error(ArgumentError, /agent is required/)
    end

    it 'raises error without validator' do
      expect {
        AgentMoveService.new(
          agent: agent,
          validator: nil,
          move_history: [],
          session: session
        )
      }.to raise_error(ArgumentError, /validator is required/)
    end
  end

  describe '#generate_move', :vcr do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'with valid LLM response' do
      it 'returns move data with all fields', vcr: { cassette_name: 'agent_move_service/valid_opening_move' } do
        result = service.generate_move

        expect(result).to be_a(Hash)
        expect(result).to have_key(:move)
        expect(result).to have_key(:prompt)
        expect(result).to have_key(:response)
        expect(result).to have_key(:tokens)
        expect(result).to have_key(:time_ms)

        # Move should be valid
        expect(validator.legal_moves).to include(result[:move])

        # Metadata should be present
        expect(result[:prompt]).to be_a(String)
        expect(result[:prompt].length).to be > 100
        expect(result[:response]).to be_a(String)
        expect(result[:tokens]).to be_a(Integer)
        expect(result[:tokens]).to be > 0
        expect(result[:time_ms]).to be_a(Integer)
        expect(result[:time_ms]).to be > 0
      end
    end

    context 'with move history' do
      let(:match) { create(:match, agent: agent) }
      let!(:move1) { create(:move, :agent_move, match: match, move_number: 1, move_notation: 'e4') }
      let!(:move2) { create(:move, :stockfish_move, match: match, move_number: 2, move_notation: 'e5') }

      let(:service) do
        validator = MoveValidator.new
        validator.apply_move('e4')
        validator.apply_move('e5')

        AgentMoveService.new(
          agent: agent,
          validator: validator,
          move_history: [move1, move2],
          session: session
        )
      end

      it 'includes move history in prompt', vcr: { cassette_name: 'agent_move_service/with_move_history' } do
        result = service.generate_move

        expect(result[:prompt]).to include('e4')
        expect(result[:prompt]).to include('e5')
        expect(result[:prompt]).to include('Move History')
      end
    end
  end

  describe '#build_prompt' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    it 'includes agent name and prompt' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include(agent.name)
      expect(prompt).to include(agent.prompt)
    end

    it 'includes current position FEN' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include('Current Position (FEN)')
      expect(prompt).to include(Chess::Game::DEFAULT_FEN)
    end

    it 'includes legal moves' do
      prompt = service.send(:build_prompt)

      expect(prompt).to include('Legal moves')
      expect(prompt).to include('e4')
      expect(prompt).to include('d4')
    end

    it 'includes move history when present' do
      match = create(:match, agent: agent)
      move1 = create(:move, match: match, move_number: 1, move_notation: 'e4')

      validator = MoveValidator.new
      validator.apply_move('e4')

      service = AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [move1],
        session: session
      )

      prompt = service.send(:build_prompt)
      expect(prompt).to include('Move History')
      expect(prompt).to include('1. e4')
    end

    it 'formats move history in standard notation' do
      match = create(:match, agent: agent)
      move1 = create(:move, match: match, move_number: 1, move_notation: 'e4', player: :agent)
      move2 = create(:move, match: match, move_number: 2, move_notation: 'e5', player: :stockfish)
      move3 = create(:move, match: match, move_number: 3, move_notation: 'Nf3', player: :agent)

      validator = MoveValidator.new
      validator.apply_move('e4')
      validator.apply_move('e5')
      validator.apply_move('Nf3')

      service = AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [move1, move2, move3],
        session: session
      )

      prompt = service.send(:build_prompt)
      expect(prompt).to include('1. e4 e5')
      expect(prompt).to include('2. Nf3')
    end
  end

  describe '#parse_move_from_response' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    it 'extracts move from "MOVE: e4" format' do
      response = "I will play e4 to control the center. MOVE: e4"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('e4')
    end

    it 'extracts move from different case' do
      response = "move: Nf3"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('Nf3')
    end

    it 'handles response with explanation after move' do
      response = "MOVE: d4\nThis controls the center and opens lines for my pieces."
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('d4')
    end

    it 'returns nil for response without move marker' do
      response = "I think e4 is the best move here."
      move = service.send(:parse_move_from_response, response)
      expect(move).to be_nil
    end

    it 'extracts first move if multiple present' do
      response = "MOVE: e4 or maybe MOVE: d4"
      move = service.send(:parse_move_from_response, response)
      expect(move).to eq('e4')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb`
Expected: FAIL - "uninitialized constant AgentMoveService"

**Step 3: Create AgentMoveService**

Create `app/services/agent_move_service.rb`:

```ruby
class AgentMoveService
  class InvalidMoveError < StandardError; end

  def initialize(agent:, validator:, move_history:, session:)
    raise ArgumentError, "agent is required" unless agent
    raise ArgumentError, "validator is required" unless validator

    @agent = agent
    @validator = validator
    @move_history = move_history
    @session = session
  end

  # Generate the agent's next move
  # Returns: {
  #   move: "e4",
  #   prompt: "...",
  #   response: "...",
  #   tokens: 150,
  #   time_ms: 500
  # }
  def generate_move
    prompt = build_prompt
    start_time = Time.now

    # Call LLM
    anthropic = AnthropicClient.new(session: @session)
    llm_response = anthropic.complete(prompt: prompt)

    time_ms = ((Time.now - start_time) * 1000).to_i

    # Parse move from response
    move = parse_move_from_response(llm_response[:content])

    unless move
      raise InvalidMoveError, "Could not parse move from response: #{llm_response[:content]}"
    end

    # Validate move
    unless @validator.valid_move?(move)
      raise InvalidMoveError, "Invalid move suggested: #{move}"
    end

    {
      move: move,
      prompt: prompt,
      response: llm_response[:content],
      tokens: llm_response[:usage][:total_tokens],
      time_ms: time_ms
    }
  end

  private

  def build_prompt
    <<~PROMPT
      You are a chess-playing AI agent named "#{@agent.name}".

      Your personality and strategy: #{@agent.prompt}

      Current Position (FEN): #{@validator.current_fen}

      #{format_move_history}

      Game Context:
      - Your color: White
      - Move number: #{next_move_number}
      - Legal moves: #{@validator.legal_moves.join(', ')}

      Analyze the position and respond with your next move.
      Format: MOVE: [your move in standard algebraic notation]

      Example responses:
      - "I'll control the center with e4. MOVE: e4"
      - "Developing the knight is best. MOVE: Nf3"

      Now choose your move:
    PROMPT
  end

  def format_move_history
    return "Move History: (game start)" if @move_history.empty?

    lines = ["Move History:"]
    @move_history.each_slice(2).with_index(1) do |pair, number|
      white_move = pair[0]
      black_move = pair[1]

      if black_move
        lines << "#{number}. #{white_move.move_notation} #{black_move.move_notation}"
      else
        lines << "#{number}. #{white_move.move_notation}"
      end
    end

    lines.join("\n")
  end

  def next_move_number
    (@move_history.length / 2) + 1
  end

  def parse_move_from_response(response)
    # Look for pattern: MOVE: <move>
    # Case insensitive, capture the move
    if response =~ /move:\s*(\S+)/i
      return $1.strip
    end

    nil
  end
end
```

**Step 4: Run test without VCR to verify structure**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb --tag ~vcr`
Expected: Tests pass except VCR tests (those will fail without cassettes)

**Step 5: Commit**

```bash
git add spec/services/agent_move_service_spec.rb app/services/agent_move_service.rb
git commit -m "feat(phase-3c): add AgentMoveService basic structure

Create AgentMoveService to:
- Build context-rich prompts for LLM
- Include agent personality, current position, legal moves, move history
- Parse move from LLM response (MOVE: notation)
- Validate parsed move against legal moves
- Return structured result with metadata

Includes tests for:
- Service initialization and validation
- Prompt building with all context
- Move history formatting (1. e4 e5 2. Nf3)
- Move parsing from various response formats

Note: VCR cassettes will be recorded in next task.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Record VCR Cassettes

**Files:**
- Create: VCR cassettes in `spec/vcr_cassettes/agent_move_service/`

**Step 1: Set up real API key for recording**

Run:
```bash
export ANTHROPIC_API_KEY="your-real-api-key"
```

**Step 2: Record cassette for valid opening move**

Run:
```bash
bundle exec rspec spec/services/agent_move_service_spec.rb \
  --tag vcr:cassette_name:agent_move_service/valid_opening_move
```

Expected: Test runs, makes real API call, records cassette

**Step 3: Record cassette with move history**

Run:
```bash
bundle exec rspec spec/services/agent_move_service_spec.rb \
  --tag vcr:cassette_name:agent_move_service/with_move_history
```

Expected: Test runs, records cassette

**Step 4: Verify cassettes were created**

Run: `ls spec/vcr_cassettes/agent_move_service/`
Expected: See two cassette files

**Step 5: Run tests without API key (using cassettes)**

Run:
```bash
unset ANTHROPIC_API_KEY
bundle exec rspec spec/services/agent_move_service_spec.rb
```

Expected: All tests pass using recorded cassettes

**Step 6: Commit cassettes**

```bash
git add spec/vcr_cassettes/agent_move_service/
git commit -m "test(phase-3c): add VCR cassettes for AgentMoveService

Record LLM interactions for:
- Valid opening move generation
- Move generation with move history

Cassettes enable fast, deterministic testing without API calls.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Retry Logic (TDD)

**Files:**
- Modify: `spec/services/agent_move_service_spec.rb`
- Modify: `app/services/agent_move_service.rb`

**Step 1: Add retry tests**

Add to `spec/services/agent_move_service_spec.rb`:

```ruby
  describe 'retry logic' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'when LLM suggests invalid move' do
      it 'retries up to 3 times', vcr: { cassette_name: 'agent_move_service/invalid_move_retry' } do
        # Mock to simulate invalid move on first try, valid on second
        allow(service).to receive(:parse_move_from_response).and_return('Ke2', 'e4')

        result = service.generate_move
        expect(result[:move]).to eq('e4')
        expect(service).to have_received(:parse_move_from_response).twice
      end

      it 'raises error after 3 failed attempts' do
        # Mock to always return invalid move
        allow(service).to receive(:parse_move_from_response).and_return('InvalidMove')

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::InvalidMoveError, /failed to produce valid move after 3 attempts/)
      end
    end

    context 'when response has no parseable move' do
      it 'retries with more explicit prompt' do
        responses = [
          "I think e4 is good",  # No MOVE: marker
          "MOVE: e4"             # Valid response
        ]

        allow_any_instance_of(AnthropicClient).to receive(:complete).and_return(
          { content: responses[0], usage: { total_tokens: 50 } },
          { content: responses[1], usage: { total_tokens: 50 } }
        )

        result = service.generate_move
        expect(result[:move]).to eq('e4')
      end
    end
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb -e "retry logic"`
Expected: FAIL - retry logic not implemented

**Step 3: Implement retry logic**

Modify `app/services/agent_move_service.rb`:

```ruby
class AgentMoveService
  class InvalidMoveError < StandardError; end

  MAX_RETRIES = 3

  # ... existing initialization code ...

  def generate_move
    retries = 0
    all_prompts = []
    all_responses = []

    loop do
      prompt = build_prompt(retry_attempt: retries)
      all_prompts << prompt
      start_time = Time.now

      # Call LLM
      anthropic = AnthropicClient.new(session: @session)
      llm_response = anthropic.complete(prompt: prompt)
      all_responses << llm_response[:content]

      time_ms = ((Time.now - start_time) * 1000).to_i

      # Parse move from response
      move = parse_move_from_response(llm_response[:content])

      # Check if move is valid
      if move && @validator.valid_move?(move)
        return {
          move: move,
          prompt: all_prompts.join("\n---RETRY---\n"),
          response: all_responses.join("\n---RETRY---\n"),
          tokens: llm_response[:usage][:total_tokens],
          time_ms: time_ms
        }
      end

      # Increment retry counter
      retries += 1

      # Give up after max retries
      if retries >= MAX_RETRIES
        error_msg = if move
          "Invalid move suggested: #{move}. Failed to produce valid move after #{MAX_RETRIES} attempts."
        else
          "Could not parse move from response. Failed after #{MAX_RETRIES} attempts."
        end

        raise InvalidMoveError, error_msg
      end

      # Continue loop to retry
    end
  end

  private

  def build_prompt(retry_attempt: 0)
    base_prompt = <<~PROMPT
      You are a chess-playing AI agent named "#{@agent.name}".

      Your personality and strategy: #{@agent.prompt}

      Current Position (FEN): #{@validator.current_fen}

      #{format_move_history}

      Game Context:
      - Your color: White
      - Move number: #{next_move_number}
      - Legal moves: #{@validator.legal_moves.join(', ')}
    PROMPT

    if retry_attempt > 0
      base_prompt += <<~RETRY

        IMPORTANT: Your previous response was invalid. Please respond EXACTLY in this format:
        MOVE: [choose ONE move from the legal moves list above]

        Example: MOVE: e4
      RETRY
    else
      base_prompt += <<~NORMAL

        Analyze the position and respond with your next move.
        Format: MOVE: [your move in standard algebraic notation]

        Example responses:
        - "I'll control the center with e4. MOVE: e4"
        - "Developing the knight is best. MOVE: Nf3"

        Now choose your move:
      NORMAL
    end

    base_prompt
  end

  # ... rest of existing methods ...
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb -e "retry logic"`
Expected: All retry tests pass

**Step 5: Commit**

```bash
git add spec/services/agent_move_service_spec.rb app/services/agent_move_service.rb
git commit -m "feat(phase-3c): add retry logic for invalid moves

Implement retry mechanism:
- Retry up to 3 times if move is invalid or unparseable
- Enhanced prompt on retry with explicit format instructions
- Accumulate all prompts/responses for debugging
- Raise error after MAX_RETRIES attempts

Handle error cases:
- LLM suggests illegal move
- Response doesn't include MOVE: marker
- Parsed move not in legal moves list

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Error Handling (TDD)

**Files:**
- Modify: `spec/services/agent_move_service_spec.rb`
- Modify: `app/services/agent_move_service.rb`

**Step 1: Add error handling tests**

Add to `spec/services/agent_move_service_spec.rb`:

```ruby
  describe 'error handling' do
    let(:service) do
      AgentMoveService.new(
        agent: agent,
        validator: validator,
        move_history: [],
        session: session
      )
    end

    context 'when LLM API fails' do
      it 'raises error with helpful message' do
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_raise(
          Faraday::Error.new('Connection failed')
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::LlmApiError, /Failed to get response from LLM/)
      end
    end

    context 'when LLM API times out' do
      it 'raises timeout error' do
        allow_any_instance_of(AnthropicClient).to receive(:complete).and_raise(
          Faraday::TimeoutError
        )

        expect {
          service.generate_move
        }.to raise_error(AgentMoveService::LlmApiError, /timeout/)
      end
    end

    context 'when session has no LLM config' do
      let(:empty_session) { {} }

      it 'raises configuration error' do
        expect {
          AgentMoveService.new(
            agent: agent,
            validator: validator,
            move_history: [],
            session: empty_session
          ).generate_move
        }.to raise_error(AgentMoveService::ConfigurationError, /LLM not configured/)
      end
    end
  end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb -e "error handling"`
Expected: FAIL - error classes not defined

**Step 3: Implement error handling**

Modify `app/services/agent_move_service.rb`:

```ruby
class AgentMoveService
  class InvalidMoveError < StandardError; end
  class LlmApiError < StandardError; end
  class ConfigurationError < StandardError; end

  MAX_RETRIES = 3

  def initialize(agent:, validator:, move_history:, session:)
    raise ArgumentError, "agent is required" unless agent
    raise ArgumentError, "validator is required" unless validator

    @agent = agent
    @validator = validator
    @move_history = move_history
    @session = session

    # Validate LLM configuration
    unless LlmConfigService.configured?(@session)
      raise ConfigurationError, "LLM not configured in session"
    end
  end

  def generate_move
    retries = 0
    all_prompts = []
    all_responses = []

    loop do
      prompt = build_prompt(retry_attempt: retries)
      all_prompts << prompt
      start_time = Time.now

      begin
        # Call LLM
        anthropic = AnthropicClient.new(session: @session)
        llm_response = anthropic.complete(prompt: prompt)
        all_responses << llm_response[:content]

        time_ms = ((Time.now - start_time) * 1000).to_i

        # Parse move from response
        move = parse_move_from_response(llm_response[:content])

        # Check if move is valid
        if move && @validator.valid_move?(move)
          return {
            move: move,
            prompt: all_prompts.join("\n---RETRY---\n"),
            response: all_responses.join("\n---RETRY---\n"),
            tokens: llm_response[:usage][:total_tokens],
            time_ms: time_ms
          }
        end

        # Increment retry counter
        retries += 1

        # Give up after max retries
        if retries >= MAX_RETRIES
          error_msg = if move
            "Invalid move suggested: #{move}. Failed to produce valid move after #{MAX_RETRIES} attempts."
          else
            "Could not parse move from response. Failed after #{MAX_RETRIES} attempts."
          end

          raise InvalidMoveError, error_msg
        end
      rescue Faraday::TimeoutError => e
        raise LlmApiError, "Failed to get response from LLM (timeout): #{e.message}"
      rescue Faraday::Error => e
        raise LlmApiError, "Failed to get response from LLM: #{e.message}"
      end

      # Continue loop to retry
    end
  end

  # ... rest of existing methods unchanged ...
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/agent_move_service_spec.rb -e "error handling"`
Expected: All error handling tests pass

**Step 5: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 6: Commit**

```bash
git add spec/services/agent_move_service_spec.rb app/services/agent_move_service.rb
git commit -m "feat(phase-3c): add error handling for LLM API failures

Add error handling for:
- API connection failures (network errors)
- API timeouts
- Missing LLM configuration in session

Define custom error classes:
- InvalidMoveError: Agent failed to produce valid move
- LlmApiError: API communication failed
- ConfigurationError: Session not configured

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verification Checklist

Before marking Phase 3c complete:

- [ ] AgentMoveService created with full structure
- [ ] Builds context-rich prompts with all game data
- [ ] Parses moves from LLM responses
- [ ] Validates moves against legal moves
- [ ] Implements retry logic (up to 3 attempts)
- [ ] Handles LLM API errors gracefully
- [ ] VCR cassettes recorded for LLM interactions
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Coverage ≥ 90% for Phase 3c code
- [ ] Tests work without real API key (using cassettes)

---

## Dependencies for Next Phases

**Phase 3d (Match Orchestration) needs:**
- AgentMoveService ✓
- MoveValidator (from 3b) ✓
- StockfishService (from 3b) ✓
- Match and Move models (from 3a) ✓

---

**Phase 3c Status:** Ready for implementation
**Estimated Time:** 2-3 hours
**Complexity:** Medium (prompt engineering, LLM integration, error handling)
