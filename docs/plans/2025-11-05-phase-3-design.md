# Phase 3: Quick Test Mode - Design Document

**Date**: 2025-11-05
**Status**: Design Complete, Ready for Planning
**Scope**: Phase 3a-3e (Match creation, execution, and real-time UI)

---

## Overview

### Goal
Enable users to test their agents by playing complete chess games against Stockfish with full observability of agent decision-making in real-time.

### Philosophy
- **Validation over perfection** - Build the smallest thing that validates the core idea
- **Maximum transparency** - Show all LLM prompts, responses, and decision data
- **Experimentation-first** - Capture every data point that might be useful for prompt iteration
- **Real-time experience** - Users watch matches unfold live, not batch results

### Success Criteria
- User can select agent + Stockfish level and start a match
- Match executes to completion (checkmate/stalemate/draw)
- User sees real-time updates: board state, moves, LLM thinking, stats
- Full game data persisted for analysis (prompts, responses, timing, tokens, cost)
- Agent can complete games without crashing or producing invalid moves

---

## Phase Breakdown

We're splitting Phase 3 into 5 sub-phases for incremental validation:

### Phase 3a: Match & Move Models + Basic CRUD
- Create Match and Move models with full analytics schema
- Database migrations
- GraphQL types and basic queries (no subscriptions yet)
- Factory setup for testing
- **Validates**: Data model is sound, can create/query matches

### Phase 3b: Stockfish Integration
- StockfishService - communicate with engine binary
- MoveValidator - validate move legality using chess gem
- Tests with known positions/moves
- **Validates**: Can talk to Stockfish, validate moves

### Phase 3c: Agent Move Generation
- AgentMoveService - construct prompt, call LLM, parse response
- Store prompt/response on Move record
- Handle API errors gracefully
- **Validates**: Agent can generate legal moves

### Phase 3d: Match Orchestration
- MatchRunner - game loop coordinating services
- createMatch mutation triggers MatchRunner
- Saves each move to database
- Background job execution via Solid Queue
- **Validates**: Full games can complete

### Phase 3e: Real-time UI
- GraphQL subscription for match updates
- Frontend chessboard component
- Move list, thinking logs, stats panels
- **Validates**: User can watch match unfold

---

## User Journey (Complete Flow)

1. User navigates to "Test Agent" page
2. Selects an existing agent from dropdown
3. Chooses Stockfish difficulty level (1-8 slider)
4. Clicks "Start Match" button
5. Redirected to match page
6. Match begins executing in background
7. User sees in real-time:
   - Chessboard updating with each move
   - Move list growing (1. e4 e5 2. Nf3...)
   - Raw LLM prompts and responses for agent moves
   - Live stats: tokens used, cost, time per move
8. Match completes with result (checkmate/stalemate/draw)
9. Final analytics displayed: total moves, opening name, winner

---

## Database Schema

### Match Model

**Table**: `matches`

```ruby
# app/models/match.rb
class Match < ApplicationRecord
  belongs_to :agent
  has_many :moves, -> { order(:move_number) }, dependent: :destroy

  enum :status, { pending: 0, in_progress: 1, completed: 2, errored: 3 }
  enum :winner, { agent: 0, stockfish: 1, draw: 2 }

  validates :stockfish_level, inclusion: { in: 1..8 }
end
```

**Columns**:
- `id` (bigint, primary key)
- `agent_id` (bigint, foreign key → agents)
- `stockfish_level` (integer, 1-8)
- `status` (enum: pending/in_progress/completed/errored)
- `winner` (enum: agent/stockfish/draw, nullable)
- `result_reason` (string, nullable) - "checkmate", "stalemate", "insufficient_material", "threefold_repetition", "fifty_move_rule"
- `started_at` (datetime, nullable)
- `completed_at` (datetime, nullable)
- `total_moves` (integer, default: 0)
- `opening_name` (string, nullable) - e.g., "Sicilian Defense"
- `total_tokens_used` (integer, default: 0)
- `total_cost_cents` (integer, default: 0) - Estimated API cost
- `average_move_time_ms` (integer, nullable)
- `final_board_state` (text, nullable) - FEN notation
- `error_message` (text, nullable) - If status=errored
- `created_at` (datetime)
- `updated_at` (datetime)

**Indexes**:
- `agent_id`
- `status`
- `created_at`

### Move Model

**Table**: `moves`

```ruby
# app/models/move.rb
class Move < ApplicationRecord
  belongs_to :match

  enum :player, { agent: 0, stockfish: 1 }

  validates :move_number, presence: true, numericality: { greater_than: 0 }
  validates :move_notation, presence: true
  validates :board_state_after, presence: true
end
```

**Columns**:
- `id` (bigint, primary key)
- `match_id` (bigint, foreign key → matches)
- `move_number` (integer) - 1-based move number
- `player` (enum: agent/stockfish)
- `move_notation` (string) - SAN notation: "e4", "Nf3", "O-O", "Qxe5+"
- `board_state_before` (text) - FEN notation before move
- `board_state_after` (text) - FEN notation after move
- `llm_prompt` (text, nullable) - Full prompt sent to LLM (agent moves only)
- `llm_response` (text, nullable) - Raw LLM response (agent moves only)
- `tokens_used` (integer, nullable) - Token count (agent moves only)
- `response_time_ms` (integer) - Time taken to generate/get move
- `created_at` (datetime)

**Indexes**:
- `match_id, move_number` (compound, unique)
- `match_id, player` (for filtering by player)

**Design Rationale**:
- Separate Move model (not JSONB) for maximum query flexibility
- Store both before/after board states for easy replay
- Full LLM interaction data on move for transparency
- Response time and tokens for cost/performance analysis

---

## Service Architecture

### MatchRunner (Orchestrator)

**Responsibility**: Coordinate the complete game loop from start to finish.

**Location**: `app/services/match_runner.rb`

**Public Interface**:
```ruby
class MatchRunner
  def initialize(match)
    @match = match
    @board = Chess::Game.new # Initialize chess board
  end

  def run!
    # Main game loop
    # Returns: updated match record
  end

  private

  def play_turn
    # Execute one move (agent or stockfish)
  end

  def broadcast_update(move)
    # Send GraphQL subscription event
  end

  def game_over?
    # Check for checkmate/stalemate/draw
  end

  def finalize_match(result)
    # Update match with final stats
  end
end
```

**Flow**:
1. Load match and initialize board
2. Update match status to `in_progress`
3. While game not over:
   - Determine whose turn (agent plays white, starts first)
   - If agent turn: call AgentMoveService
   - If stockfish turn: call StockfishService
   - Validate move with MoveValidator
   - Apply move to board
   - Create Move record with all data
   - Broadcast update via GraphQL subscription
   - Check for game over conditions
4. Finalize match with result and stats
5. Update match status to `completed`

**Error Handling**:
- If agent produces invalid move → retry up to 3 times with different prompt
- After 3 failures → forfeit game (stockfish wins)
- If Stockfish crashes → log error, mark match as errored
- Any unexpected exception → mark match as errored with error_message

### AgentMoveService

**Responsibility**: Generate agent's next move by calling LLM with full game context.

**Location**: `app/services/agent_move_service.rb`

**Public Interface**:
```ruby
class AgentMoveService
  def initialize(agent:, board_state:, move_history:, game_metadata:)
    @agent = agent
    @board_state = board_state # Chess::Game object
    @move_history = move_history # Array of Move objects
    @game_metadata = game_metadata # Hash with context
  end

  def generate_move
    # Returns: {
    #   move: "e4",
    #   prompt: "You are playing chess...",
    #   response: "I will play e4 because...",
    #   tokens: 150,
    #   time_ms: 500
    # }
  end

  private

  def build_prompt
    # Construct LLM prompt with all context
  end

  def parse_move_from_response(response)
    # Extract move notation from LLM response
  end
end
```

**Prompt Structure** (passed to LLM):
```
You are a chess-playing AI agent named "{agent.name}".

Your prompt/personality: {agent.prompt}

Current Position (FEN): {board_state.fen}

Move History:
1. e4 e5
2. Nf3 Nc6
3. Bb5 a6

Game Context:
- Opponent: Stockfish Level {level}
- Your color: White
- Move number: 4
- Legal moves: Ba4, Bxc6, Bc4, Be2, Bf1, O-O, ...

Analyze the position and respond with your next move.
Format: MOVE: [your move in standard algebraic notation]
```

**Parsing Logic**:
- Look for pattern: `MOVE: {move}`
- Validate move is in legal moves list
- If ambiguous, try to match against legal moves
- If unparseable, return error for retry

**LLM Call**:
- Use AnthropicClient from Phase 2b
- Get API config from session (via context passed down)
- Track tokens and response time
- Handle API errors (timeout, rate limit, invalid key)

### StockfishService

**Responsibility**: Get Stockfish engine's move for a given position.

**Location**: `app/services/stockfish_service.rb`

**Public Interface**:
```ruby
class StockfishService
  def initialize(level: 5)
    @level = level # 1-8
    @engine = spawn_engine
  end

  def get_move(board_fen)
    # Returns: {
    #   move: "e4",
    #   time_ms: 50
    # }
  end

  private

  def spawn_engine
    # Start stockfish process
  end

  def configure_strength(level)
    # Set UCI options for skill level
  end

  def send_command(cmd)
    # Send UCI command to engine
  end
end
```

**UCI Commands** (Stockfish Protocol):
```
uci                          # Initialize engine
setoption name Skill Level value {0-20}  # Set difficulty (1-8 → 0-20)
position fen {fen_string}    # Set board position
go movetime 1000             # Think for 1 second
# Engine responds: bestmove e2e4
```

**Skill Level Mapping**:
- Level 1 → UCI Skill Level 0-2
- Level 2 → UCI Skill Level 3-5
- Level 3 → UCI Skill Level 6-8
- Level 4 → UCI Skill Level 9-11
- Level 5 → UCI Skill Level 12-14
- Level 6 → UCI Skill Level 15-17
- Level 7 → UCI Skill Level 18-19
- Level 8 → UCI Skill Level 20 (full strength)

**Error Handling**:
- Stockfish crashes → raise StockfishError
- Timeout → kill process, raise error
- Invalid position → raise ValidationError

### MoveValidator

**Responsibility**: Validate move legality using chess library.

**Location**: `app/services/move_validator.rb`

**Public Interface**:
```ruby
class MoveValidator
  def initialize(board)
    @board = board # Chess::Game object
  end

  def valid_move?(move_san)
    # Returns: true/false
  end

  def legal_moves
    # Returns: Array of legal moves in SAN
  end

  def apply_move(move_san)
    # Apply move and return new board state
    # Raises: IllegalMoveError if invalid
  end
end
```

**Chess Library**: Use `chess` gem (https://github.com/pioz/chess)
- Provides full chess rules implementation
- FEN parsing and generation
- Move validation
- Game state detection (check, checkmate, stalemate)

**Alternative**: `ruby-chess` gem if `chess` has issues

---

## GraphQL API

### Type Definitions

#### MatchType

**File**: `app/graphql/types/match_type.rb`

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

    # Analytics fields
    field :total_tokens_used, Integer, null: false
    field :total_cost_cents, Integer, null: false,
      description: "Estimated API cost in cents"
    field :average_move_time_ms, Integer, null: true,
      description: "Average time per move in milliseconds"
    field :final_board_state, String, null: true,
      description: "Final position in FEN notation"

    field :moves, [Types::MoveType], null: false
    field :error_message, String, null: true

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
```

#### MoveType

**File**: `app/graphql/types/move_type.rb`

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

    # LLM interaction data (agent moves only)
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

#### Enums

**File**: `app/graphql/types/match_status_enum.rb`

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

**File**: `app/graphql/types/match_winner_enum.rb`

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

**File**: `app/graphql/types/move_player_enum.rb`

```ruby
module Types
  class MovePlayerEnum < Types::BaseEnum
    description "Which player made a move"

    value "AGENT", "Agent's move", value: "agent"
    value "STOCKFISH", "Stockfish's move", value: "stockfish"
  end
end
```

### Mutations

#### CreateMatch

**File**: `app/graphql/mutations/create_match.rb`

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

      # Enqueue background job
      MatchExecutionJob.perform_later(match.id)

      { match: match, errors: [] }
    end
  end
end
```

**Register in MutationType**:
```ruby
field :create_match, mutation: Mutations::CreateMatch
```

### Queries

**Add to QueryType** (`app/graphql/types/query_type.rb`):

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
  scope = Match.all.order(created_at: :desc)
  scope = scope.where(agent_id: agent_id) if agent_id
  scope = scope.where(status: status) if status
  scope
end
```

### Subscriptions

#### MatchUpdated

**File**: `app/graphql/types/subscription_type.rb`

```ruby
module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :match_updated, Types::MatchUpdatePayloadType, null: false,
      description: "Subscribe to real-time updates for a match" do
      argument :match_id, ID, required: true
    end

    def match_updated(match_id:)
      # Subscription is triggered by MatchRunner broadcasting
      # No implementation needed here
    end
  end
end
```

**File**: `app/graphql/types/match_update_payload_type.rb`

```ruby
module Types
  class MatchUpdatePayloadType < Types::BaseObject
    description "Payload for match update subscription"

    field :match, Types::MatchType, null: false,
      description: "Updated match state"
    field :latest_move, Types::MoveType, null: true,
      description: "The move that was just played"
  end
end
```

**Broadcasting from MatchRunner**:

```ruby
# In MatchRunner#broadcast_update(move)
PromptChessSchema.subscriptions.trigger(
  :match_updated,
  { match_id: @match.id.to_s },
  {
    match: @match.reload,
    latest_move: move
  }
)
```

**GraphQL Schema Configuration**:

```ruby
# app/graphql/prompt_chess_schema.rb
class PromptChessSchema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)

  use GraphQL::Subscriptions::ActionCableSubscriptions
end
```

---

## Background Job

### MatchExecutionJob

**File**: `app/jobs/match_execution_job.rb`

```ruby
class MatchExecutionJob < ApplicationJob
  queue_as :default

  def perform(match_id)
    match = Match.find(match_id)

    # Run the match
    runner = MatchRunner.new(match)
    runner.run!
  rescue StandardError => e
    # Mark match as errored
    match.update!(
      status: :errored,
      error_message: "#{e.class}: #{e.message}"
    )

    # Re-raise for job retry logic
    raise
  end
end
```

**Job Configuration** (Solid Queue):
- Default queue
- No special priority (FIFO)
- Retry: 3 attempts with exponential backoff
- Timeout: 30 minutes (chess games can be long)

---

## Match Execution Flow

### Detailed Sequence

1. **User triggers createMatch mutation**
   - GraphQL receives request
   - Validates agent exists and stockfish_level is 1-8
   - Checks LLM is configured in session
   - Creates Match record (status: pending)
   - Enqueues MatchExecutionJob
   - Returns match to client

2. **Client subscribes to matchUpdated**
   - GraphQL subscription established via Action Cable
   - Client waits for updates

3. **MatchExecutionJob executes**
   - Loads Match record
   - Initializes MatchRunner
   - Calls `runner.run!`

4. **MatchRunner.run! game loop**
   ```ruby
   def run!
     @match.update!(status: :in_progress, started_at: Time.current)

     while !game_over?
       move = play_turn
       broadcast_update(move)
     end

     finalize_match
   end
   ```

5. **play_turn for agent's move**
   - Builds game context (board state, move history, metadata)
   - Calls AgentMoveService.generate_move
   - AgentMoveService constructs prompt with full context
   - Calls AnthropicClient (from Phase 2b) with agent's prompt
   - Parses move from LLM response
   - Validates move with MoveValidator
   - If invalid: retry up to 3 times with modified prompt
   - If still invalid: forfeit game
   - Creates Move record with llm_prompt, llm_response, tokens, timing
   - Updates @match stats (total_tokens_used, total_cost_cents)
   - Returns Move object

6. **play_turn for Stockfish's move**
   - Calls StockfishService.get_move(fen)
   - StockfishService sends UCI commands
   - Parses bestmove from engine
   - Validates move (should always be legal)
   - Creates Move record with timing
   - Returns Move object

7. **broadcast_update after each move**
   - Triggers GraphQL subscription
   - Sends updated match + latest move to all subscribers
   - Client receives update, re-renders UI

8. **game_over? check**
   - Uses chess library to detect:
     - Checkmate
     - Stalemate
     - Insufficient material
     - Threefold repetition
     - Fifty-move rule
   - Returns true if any condition met

9. **finalize_match**
   - Determines winner and result_reason
   - Calculates final stats:
     - total_moves
     - average_move_time_ms
     - opening_name (from move history)
   - Updates Match record:
     - status: completed
     - winner: agent/stockfish/draw
     - result_reason
     - completed_at
     - final_board_state (FEN)
   - Broadcasts final update

10. **Client receives completion**
    - Subscription receives final match state
    - UI shows result and full game analytics

### Error Scenarios

**Agent produces invalid move:**
```ruby
# In AgentMoveService
MAX_RETRIES = 3
retries = 0

loop do
  move = parse_move_from_response(llm_response)

  if validator.valid_move?(move)
    return move
  else
    retries += 1
    break if retries >= MAX_RETRIES

    # Retry with enhanced prompt
    prompt = build_retry_prompt(move, validator.legal_moves)
    llm_response = call_llm(prompt)
  end
end

# After 3 retries, raise error
raise InvalidMoveError, "Agent failed to produce valid move after #{MAX_RETRIES} attempts"
```

**Stockfish crashes:**
```ruby
# In StockfishService
def get_move(fen)
  send_command("position fen #{fen}")
  send_command("go movetime 1000")

  response = read_response(timeout: 5)
  parse_bestmove(response)
rescue Errno::EPIPE, IOError
  raise StockfishError, "Stockfish process died"
rescue Timeout::Error
  raise StockfishError, "Stockfish timed out"
end
```

**LLM API error:**
```ruby
# In AgentMoveService
begin
  response = anthropic_client.complete(prompt: prompt)
rescue Faraday::Error => e
  raise LlmApiError, "Failed to get response from LLM: #{e.message}"
end
```

**All errors bubble up to MatchExecutionJob:**
```ruby
# Job marks match as errored and re-raises for retry
rescue StandardError => e
  match.update!(status: :errored, error_message: e.message)
  raise
end
```

---

## Frontend UI Design (Phase 3e)

### Match Page Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Match #123 - AgentName vs Stockfish Level 5                │
│ Status: In Progress                                          │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐  ┌──────────────────────────────────┐
│                      │  │ Move List                        │
│   Chess Board        │  │ 1. e4    e5                      │
│   (8x8 visual)       │  │ 2. Nf3   Nc6                     │
│                      │  │ 3. Bb5   a6                      │
│   ♜ ♞ ♝ ♛ ♚ ♝ ♞ ♜   │  │ 4. Ba4   Nf6                     │
│   ♟ ♟ ♟ ♟ ♟ ♟ ♟ ♟   │  │ 5. O-O   Be7                     │
│   · · · · · · · ·   │  │ 6. Re1   ...                     │
│   ...                │  │                                  │
│                      │  └──────────────────────────────────┘
│   ♙ ♙ ♙ ♙ ♙ ♙ ♙ ♙   │
│   ♖ ♘ ♗ ♕ ♔ ♗ ♘ ♖   │  ┌──────────────────────────────────┐
│                      │  │ Thinking Log (Latest)            │
└──────────────────────┘  │                                  │
                          │ Agent's Turn (Move 7):           │
┌──────────────────────┐  │                                  │
│ Match Stats          │  │ Prompt:                          │
│ Moves: 12            │  │ "You are playing chess...        │
│ Tokens: 3,450        │  │ Current position (FEN): ...      │
│ Cost: $0.05          │  │ Analyze and respond with move."  │
│ Avg time: 850ms      │  │                                  │
│ Opening: Ruy Lopez   │  │ Response:                        │
└──────────────────────┘  │ "Looking at the position, I see  │
                          │ the center is controlled. I'll   │
                          │ develop my bishop. MOVE: Bb5"    │
                          │                                  │
                          │ Result: Bb5 (valid, 750ms)       │
                          └──────────────────────────────────┘
```

### Components (ViewComponent)

**MatchPageComponent** (`app/components/match_page_component.rb`)
- Root component for match page
- Establishes GraphQL subscription
- Renders child components

**ChessBoardComponent** (`app/components/chess_board_component.rb`)
- Displays 8x8 board with pieces
- Updates when match.moves changes
- Shows current position from latest move's board_state_after

**MoveListComponent** (`app/components/move_list_component.rb`)
- Shows moves in standard notation
- Auto-scrolls to latest move
- Highlights current move

**ThinkingLogComponent** (`app/components/thinking_log_component.rb`)
- Shows latest agent move's LLM interaction
- Displays prompt and response in collapsible sections
- Shows timing and token data

**MatchStatsComponent** (`app/components/match_stats_component.rb`)
- Live updating stats panel
- Badges for key metrics
- Progress indicators

### Stimulus Controllers

**match_subscription_controller.js**
- Establishes GraphQL subscription via ActionCable
- Handles matchUpdated events
- Triggers Turbo Stream updates

**chess_board_controller.js**
- Minimal JS for board interactions (if needed)
- Handles highlighting last move
- Could support move preview (future)

### GraphQL Subscription Client

```javascript
// app/javascript/controllers/match_subscription_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static values = { matchId: String }

  connect() {
    this.subscription = consumer.subscriptions.create(
      {
        channel: "GraphqlChannel",
        channelId: `MatchUpdated:${this.matchIdValue}`
      },
      {
        received: (data) => {
          // Turbo will update the page automatically
          console.log("Match update received:", data)
        }
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }
}
```

---

## Testing Strategy

### Unit Tests

**Match Model** (`spec/models/match_spec.rb`)
- Validations (stockfish_level 1-8)
- Associations (belongs_to agent, has_many moves)
- Enums (status, winner)
- Scopes (by_agent, by_status)

**Move Model** (`spec/models/move_spec.rb`)
- Validations (move_number > 0, notation present)
- Associations (belongs_to match)
- Enums (player)
- Ordering (by move_number)

**Services** (all with full coverage)
- `MatchRunner` - game loop logic
- `AgentMoveService` - prompt building, move parsing
- `StockfishService` - UCI communication (mocked)
- `MoveValidator` - move validation (uses chess gem)

**GraphQL** (`spec/requests/graphql/`)
- Mutations: createMatch
- Queries: match, matches
- Subscriptions: matchUpdated (test with mock triggers)

### Integration Tests

**Full Match Flow** (`spec/system/match_execution_spec.rb`)
- Create match via GraphQL
- Job executes
- Match completes with moves
- All data persisted correctly

**Real-time Updates** (`spec/system/match_subscription_spec.rb`)
- User watches match page
- Sees updates arrive in real-time
- UI reflects current game state

### VCR Cassettes

**LLM Responses** (`spec/vcr_cassettes/agent_move_service/`)
- Agent valid move response
- Agent invalid move response (retry scenario)
- Agent API timeout
- Agent rate limit error

### Test Fixtures

**Chess Positions** (`spec/fixtures/chess_positions.yml`)
- Starting position
- Mid-game positions
- Checkmate positions
- Stalemate positions
- Common openings

**Factory Examples**:
```ruby
FactoryBot.define do
  factory :match do
    agent
    stockfish_level { 5 }
    status { :pending }
  end

  factory :move do
    match
    move_number { 1 }
    player { :agent }
    move_notation { "e4" }
    board_state_before { "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" }
    board_state_after { "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1" }
    response_time_ms { 500 }
  end
end
```

---

## Dependencies

### New Gems

Add to `Gemfile`:

```ruby
# Chess engine and logic
gem 'chess', '~> 0.3' # Ruby chess library for move validation

# Stockfish binary (via buildpack in production)
# Development: brew install stockfish
```

### Stockfish Installation

**Development (macOS)**:
```bash
brew install stockfish
```

**Production (Heroku)**:
- Use custom buildpack: https://github.com/chess-seventh/heroku-buildpack-stockfish
- Add to `.buildpacks`:
  ```
  https://github.com/heroku/heroku-buildpack-ruby
  https://github.com/chess-seventh/heroku-buildpack-stockfish
  ```

**Verify Installation**:
```bash
stockfish
> uci
uciok
```

---

## Security Considerations

### API Key Usage
- LLM calls use API credentials from session (Phase 2b)
- No API keys stored in Match or Move records
- If session expires mid-match, job fails gracefully

### Stockfish Sandboxing
- Stockfish runs as subprocess
- No arbitrary command execution
- Process killed if timeout exceeded
- Output sanitized before parsing

### Data Exposure
- Match data is per-user session (no cross-user visibility in MVP)
- All matches visible to session owner
- No authentication yet (Phase 2e handles accounts)

---

## Performance Considerations

### Match Execution
- Matches run in background jobs (non-blocking)
- One match per job (no parallelization needed for MVP)
- Job timeout: 30 minutes (prevents infinite games)
- Stockfish move time: 1 second (fast enough, not too weak)

### Database
- Indexes on match.agent_id, match.status, match.created_at
- Compound index on moves (match_id, move_number)
- FEN strings stored as text (could compress in future)

### Subscriptions
- Action Cable scales to ~1000 concurrent connections on Heroku
- Each match has 1-2 active subscribers (user + maybe observer)
- MVP: <10 concurrent matches expected

### Optimization Opportunities (Future)
- Cache opening names (first 10 moves → ECO code)
- Compress FEN strings with zlib
- JSONB summary on Match for fast queries
- Rate limit match creation (prevent abuse)

---

## Implementation Order (Sub-Phases)

### Phase 3a: Models + GraphQL Types
1. Generate Match and Move models
2. Write migrations with full schema
3. Create factories
4. Write model tests
5. Create GraphQL types (Match, Move, enums)
6. Create basic queries (match, matches)
7. Test GraphQL queries
8. Commit: "feat(phase-3a): add Match and Move models with GraphQL types"

### Phase 3b: Stockfish Integration
1. Add chess gem to Gemfile
2. Create StockfishService with UCI communication
3. Create MoveValidator using chess gem
4. Write tests with known positions
5. Test Stockfish installation locally
6. Commit: "feat(phase-3b): add Stockfish and move validation services"

### Phase 3c: Agent Move Generation
1. Create AgentMoveService
2. Implement prompt building with full context
3. Implement move parsing from LLM response
4. Write tests with VCR cassettes
5. Test retry logic for invalid moves
6. Commit: "feat(phase-3c): add agent move generation service"

### Phase 3d: Match Orchestration
1. Create MatchRunner service
2. Implement game loop
3. Create MatchExecutionJob
4. Create createMatch mutation
5. Write integration tests
6. Test full match execution locally
7. Commit: "feat(phase-3d): add match orchestration and execution"

### Phase 3e: Real-time UI
1. Add GraphQL subscription type
2. Configure Action Cable for subscriptions
3. Implement broadcast in MatchRunner
4. Create match page view
5. Create ViewComponents (board, moves, logs, stats)
6. Create Stimulus subscription controller
7. Style with Tailwind
8. Test real-time updates
9. Commit: "feat(phase-3e): add real-time match UI with subscriptions"

---

## Future Enhancements (Out of Scope for Phase 3)

- **Match History Page** - Browse past matches
- **Agent Statistics** - Win rate, average tokens, cost per game
- **Stockfish Analysis Mode** - Post-game analysis with engine evaluation
- **Opening Book** - Detect and name openings from move history
- **PGN Export** - Download games in standard chess format
- **Move Annotations** - Add commentary to interesting moves
- **Agent vs Agent Matches** - Two agents play each other
- **Tournament Mode** - Multiple matches, bracket system
- **Time Controls** - Limit thinking time per move or per game

---

## Success Metrics for Phase 3

**Validation Criteria:**
- [ ] User can start a match and see it complete
- [ ] Agent produces legal moves (or properly forfeits after retries)
- [ ] Stockfish plays without crashing
- [ ] Full game data persisted (prompts, responses, timing, tokens)
- [ ] Real-time UI updates during match
- [ ] Match completes with correct result (checkmate/stalemate/draw)
- [ ] All tests pass (unit, integration, system)
- [ ] Coverage ≥ 90% for Phase 3 code

**Non-Goals (Explicitly Out of Scope):**
- Agent winning any games (that's for prompt iteration)
- Fast match execution (optimization comes later)
- Beautiful UI (functional is enough for MVP)
- Perfect LLM prompt (we're building the infrastructure)

---

## Design Status

**Status**: ✅ Design Complete and Validated
**Next Step**: Create implementation plans for each sub-phase (3a → 3e)
**Branch Strategy**: Use `feature/phase-3a`, `feature/phase-3b`, etc. for each sub-phase

---

**Design completed**: 2025-11-05
**Ready for**: Implementation Planning (starting with Phase 3a)
