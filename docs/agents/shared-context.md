# Shared Agent Context

**Last Updated**: 2025-11-05
**Purpose**: Common knowledge and patterns shared across all specialized agents

---

## Project Overview

**Chess Prompt League MVP** - A platform where LLM agents play chess against Stockfish. Users create agents with custom prompts, test them against varying difficulty levels, and observe the agent's decision-making process in real-time.

### Core Goal
Prove that well-prompted agents can beat Stockfish level 5 through clever prompt engineering.

### MVP Philosophy
- **Validation over perfection** - Build the smallest thing that validates the core idea
- **Maximum transparency** - Show all LLM prompts, responses, and decision data
- **Experimentation-first** - Capture every data point that might be useful for prompt iteration
- **Real-time experience** - Users watch matches unfold live

---

## Chess Domain Knowledge

### Notation Systems

**FEN (Forsyth-Edwards Notation)** - Complete board state
```
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
│                                             │ │  │ │ │
│                                             │ │  │ │ └─ Fullmove number
│                                             │ │  │ └─── Halfmove clock (50-move rule)
│                                             │ │  └───── En passant target square
│                                             │ └──────── Castling availability (KQkq)
│                                             └────────── Active color (w/b)
└────────────────────────────────────────────────────── Piece positions (rank 8 to 1)
```

**SAN (Standard Algebraic Notation)** - Human-readable moves
```
e4      - Pawn to e4
Nf3     - Knight to f3
Bxe5    - Bishop captures on e5
O-O     - Kingside castling
Qh4+    - Queen to h4 with check
Qxf7#   - Queen captures f7, checkmate
```

**UCI (Universal Chess Interface)** - Engine communication
```
e2e4    - Move from e2 to e4
e7e5    - Move from e7 to e5
e1g1    - Castling (king moves)
```

### Game States

- **Check**: King is under attack but can escape
- **Checkmate**: King is under attack with no escape (game over)
- **Stalemate**: No legal moves but not in check (draw)
- **Insufficient Material**: Not enough pieces to checkmate (draw)
- **Threefold Repetition**: Same position occurs 3 times (draw)
- **Fifty-Move Rule**: 50 moves without capture or pawn move (draw)

### Chess Gem Integration

We use the `chess` gem (~> 0.3) for move validation:
```ruby
game = Chess::Game.new
game.moves                    # => Array of legal moves in SAN
game.move('e4')               # => true if legal
game.fen                      # => Current position
game.checkmate?               # => Boolean
game.stalemate?               # => Boolean
```

---

## LLM Integration Patterns

### Session-Based API Configuration

**No user accounts in MVP** - API credentials stored in session:
```ruby
session[:llm_config] = {
  provider: 'anthropic',     # 'openai', 'ollama', 'custom'
  api_key: 'encrypted_key',  # Encrypted at rest
  model: 'claude-3-5-sonnet-20241022',
  base_url: nil              # Optional for custom providers
}
```

**Security**: API keys never stored in database, only in session.

### Cost Tracking

Track every LLM call for user transparency:
```ruby
# On each agent move
{
  tokens_used: 150,                    # Total tokens (input + output)
  response_time_ms: 750,               # API call duration
  estimated_cost_cents: 0.02           # Calculated from tokens
}

# Accumulated on Match
match.total_tokens_used              # Sum of all agent moves
match.total_cost_cents               # Estimated total cost
match.average_move_time_ms           # For optimization insights
```

**Cost Formula** (Anthropic Claude Sonnet):
- Input: $3 per 1M tokens
- Output: $15 per 1M tokens
- Store separate input/output counts for accuracy

### Retry Strategy

**Philosophy**: LLMs are non-deterministic, retries often succeed.

```ruby
MAX_RETRIES = 3

loop do
  response = call_llm(prompt)
  move = parse_move(response)

  return move if valid_move?(move)

  retries += 1
  break if retries >= MAX_RETRIES

  # Enhanced prompt on retry
  prompt = build_retry_prompt(legal_moves)
end

raise InvalidMoveError after MAX_RETRIES
```

**Key Pattern**: Accumulate all prompts/responses for debugging.

### VCR Cassette Organization

Record LLM interactions for fast, deterministic tests:
```
spec/vcr_cassettes/
  agent_move_service/
    valid_opening_move.yml
    invalid_move_retry.yml
    with_move_history.yml
  match_runner/
    full_game.yml
    checkmate.yml
```

**Important**: Filter API keys in cassettes:
```ruby
VCR.configure do |c|
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
end
```

---

## Architecture Patterns

### Service Object Design

**Services are stateless operations** with clear inputs/outputs:
```ruby
class SomeService
  def initialize(dependencies)
    # Inject all dependencies
    @validator = dependencies[:validator]
    @session = dependencies[:session]
  end

  def call
    # Single responsibility
    # Return structured hash or raise specific error
    { result: data, metadata: info }
  end
end
```

**Anti-pattern**: Services that mutate instance variables over multiple calls.

### Background Job Strategy

**Solid Queue** (Rails 8 default) for match execution:
```ruby
class MatchExecutionJob < ApplicationJob
  queue_as :default

  def perform(match_id, session)
    match = Match.find(match_id)
    runner = MatchRunner.new(match: match, session: session)
    runner.run!
  rescue => e
    match.update!(status: :errored, error_message: e.message)
    raise # Re-raise for retry logic
  end
end
```

**Key Pattern**: Pass `session` to jobs for API credentials access.

**Retry Logic**: 3 attempts with exponential backoff (Rails default).

### Real-time Updates

**GraphQL Subscriptions** via Action Cable:
```ruby
# Broadcast from service
PromptChessSchema.subscriptions.trigger(
  :match_updated,
  { match_id: match.id.to_s },
  { match: match.reload, latest_move: move }
)

# Subscribe from client
subscription {
  matchUpdated(matchId: "123") {
    match { status totalMoves }
    latestMove { moveNotation }
  }
}
```

**Pattern**: Broadcast after each state change (move, status update).

---

## Error Handling Philosophy

### Graceful Degradation

**Principle**: Capture errors, mark match as errored, preserve all data.

```ruby
begin
  runner.run!
rescue AgentMoveService::InvalidMoveError => e
  # Agent failed after retries → forfeit
  match.update!(
    status: :errored,
    error_message: "Agent failed: #{e.message}",
    winner: :stockfish
  )
rescue StockfishService::StockfishError => e
  # Engine crashed → can't continue
  match.update!(
    status: :errored,
    error_message: "Stockfish error: #{e.message}"
  )
rescue => e
  # Unexpected error → preserve for debugging
  match.update!(
    status: :errored,
    error_message: "#{e.class}: #{e.message}"
  )
  raise # Re-raise for job retry
end
```

### Custom Error Classes

Define specific errors for different failure modes:
```ruby
class AgentMoveService
  class InvalidMoveError < StandardError; end
  class LlmApiError < StandardError; end
  class ConfigurationError < StandardError; end
end
```

**Why**: Enables specific rescue logic and better error messages.

---

## Testing Strategy

### Test Organization

```
spec/
  models/           # Unit tests - validations, associations, scopes
  services/         # Service tests - mock external dependencies
  jobs/             # Job tests - inline queue adapter
  requests/         # GraphQL endpoint tests
  integration/      # Cross-service tests
  system/           # Full user flow with Capybara
```

### TDD Workflow (Non-Negotiable)

**Red → Green → Refactor**

1. **Red**: Write failing test first
2. **Green**: Write minimal code to pass
3. **Refactor**: Improve without changing behavior
4. **Commit**: After each complete cycle

**Use**: `superpowers:test-driven-development` skill for all implementation.

### Factory Design Principles

**Create realistic, reusable test data**:
```ruby
FactoryBot.define do
  factory :match do
    agent
    stockfish_level { 5 }
    status { :pending }

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      total_moves { 42 }
    end

    trait :agent_won do
      completed
      winner { :agent }
      result_reason { 'checkmate' }
    end
  end
end
```

**Pattern**: Use traits for common variations.

### Coverage Requirements

- **Minimum 90% line coverage** (enforced by SimpleCov)
- **100% coverage for critical paths**: Move validation, game-over detection, API key handling
- **Focus on edge cases**: Timeouts, retries, invalid inputs, concurrent updates

---

## Security Considerations

### API Key Handling

**Never log or persist plaintext keys**:
```ruby
# ✅ Good
Rails.logger.info("LLM call completed in #{duration}ms")

# ❌ Bad
Rails.logger.info("Called LLM with key #{api_key}")
```

**Session encryption**: Rails encrypts session cookies by default.

### Subprocess Safety (Stockfish)

**Stockfish runs as subprocess** - potential security risk:
```ruby
# ✅ Good - controlled input
send_command("position fen #{fen}")
send_command("go movetime 1000")

# ❌ Bad - never allow user input directly
send_command(params[:raw_command])  # NEVER!
```

**Mitigation**:
- Validate FEN format before passing to engine
- Timeout enforcement (kill process after 5 seconds)
- Process isolation (no shell access)

### SQL Injection Prevention

**Always use parameterized queries**:
```ruby
# ✅ Good
Match.where(agent_id: params[:agent_id])

# ❌ Bad
Match.where("agent_id = #{params[:agent_id]}")
```

Rails does this automatically, but be aware in raw SQL.

---

## Performance Considerations

### Database Indexes

**Index all foreign keys and filter columns**:
```ruby
add_index :matches, :agent_id
add_index :matches, :status
add_index :matches, :created_at
add_index :moves, [:match_id, :move_number], unique: true
```

### N+1 Query Prevention

**Eager load associations in GraphQL resolvers**:
```ruby
# ✅ Good
def matches
  Match.includes(:agent, :moves).order(created_at: :desc)
end

# ❌ Bad - causes N+1
def matches
  Match.all  # Each match.agent will query separately
end
```

### Background Job Optimization

**Match execution can be slow (30+ moves, 15+ seconds each)**:
- Run in background job (never block HTTP request)
- Timeout: 30 minutes for full game
- Consider job priority for different Stockfish levels

---

## Collaboration Patterns

### When to Consult Other Specialists

**Architecture Agent** → consult for:
- New service object design
- Database schema changes
- Background job strategy changes

**GraphQL Specialist** → consult for:
- New types or mutations
- Query optimization
- Subscription patterns

**Rails Specialist** → consult for:
- Controller organization
- Hotwire integration
- ViewComponent structure

**Testing Specialist** → consult for:
- Factory design
- VCR cassette organization
- Integration test patterns

**Reviewer Agent** → always consult after:
- Completing a phase or major feature
- Before merging to main
- When test coverage drops

### Handoff Protocol

When completing work, provide:
1. **What was built** - Summary with file paths
2. **How to test** - Commands to verify
3. **Open questions** - Unresolved decisions
4. **Next steps** - What should happen next

---

## Common Pitfalls to Avoid

### Chess-Specific
- ❌ Assuming moves are always valid (always validate)
- ❌ Forgetting en passant and castling in FEN parsing
- ❌ Not handling stalemate (it's a draw, not a loss)
- ❌ Mixing up move numbers (they increment per pair, not per move)

### LLM-Specific
- ❌ Not handling API timeouts (always have timeout)
- ❌ Assuming first response is valid (implement retries)
- ❌ Not logging full prompt/response (needed for debugging)
- ❌ Hardcoding model names (use configuration)

### Rails-Specific
- ❌ Mutating objects in views (use presenters/components)
- ❌ Long-running operations in controllers (use jobs)
- ❌ Not handling race conditions in subscriptions
- ❌ Forgetting to close external processes (Stockfish)

### Testing-Specific
- ❌ Tests that depend on external APIs (use VCR)
- ❌ Tests that depend on order (use proper isolation)
- ❌ Not testing error paths (errors are features)
- ❌ Brittle tests tied to exact strings (use patterns)

---

## Resources & References

### Project Documentation
- `context.md` - Overall project context and decisions
- `docs/plans/` - Implementation plans for each phase
- `docs/agents/` - This directory, specialized agent contexts

### External Documentation
- [Chess Gem](https://github.com/pioz/chess) - Move validation library
- [Stockfish UCI Protocol](https://www.chessprogramming.org/UCI) - Engine communication
- [GraphQL Ruby](https://graphql-ruby.org/) - GraphQL implementation
- [ViewComponent](https://viewcomponent.org/) - Component framework
- [Solid Queue](https://github.com/rails/solid_queue) - Background jobs

### Chess Resources
- [FEN Notation](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation)
- [SAN Notation](https://en.wikipedia.org/wiki/Algebraic_notation_(chess))
- [Chess Programming Wiki](https://www.chessprogramming.org/)

---

**Remember**: This is an MVP. Prioritize working software over perfect architecture. Capture data for future optimization rather than optimizing prematurely.
