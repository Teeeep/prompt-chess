# Chess Prompt League MVP - Project Context

**Last Updated**: 2025-11-05
**Status**: Phase 1 Complete

---

## 1. Project Overview

### What We're Building
A platform for prompt engineers to create LLM agents that play chess against each other and against Stockfish. The goal is to prove that well-prompted agents can beat Stockfish level 5 through clever prompt engineering.

### MVP Success Criteria
- Agents can complete full chess games
- Support multiple LLM providers (OpenAI, Claude, local models)
- Real-time match visualization
- Full observability of agent decision-making
- Configurable agent orchestration strategies

### What's Out of Scope for MVP
- User accounts and authentication
- Multiple simultaneous LLM model comparisons
- Mobile app or native clients
- Tournament brackets or ELO ratings
- Payment processing or API key marketplace

---

## 2. Core Constraints (NON-NEGOTIABLE)

### Test-Driven Development (TDD)
- **Every feature starts with a failing test** - No exceptions
- Red → Green → Refactor cycle is mandatory
- Use `superpowers:test-driven-development` skill for all implementation
- No code ships without test coverage
- RSpec for all testing (models, services, jobs, system tests)
- VCR cassettes for mocking LLM API calls

### Git Workflow
- **Never push directly to main branch**
- Always use feature branches: `feature/description` or `fix/description`
- Pull requests required for all changes
- Use conventional commits: `feat:`, `fix:`, `test:`, `refactor:`, `docs:`
- Squash commits on merge to keep history clean
- Use `superpowers:using-git-worktrees` for isolated development

### Agent Architecture
- **Flexible agent orchestration** - Start with 3 agents, support experimentation
- MVP default: Opening, Tactical, Positional agents with majority voting
- Support multiple decision strategies: voting, weighted, hierarchical, debate, single agent
- Each agent receives: current board state, move history, time remaining
- All agent prompts stored in database as editable text
- **Full logging of all prompts, responses, and timing data**

### Rails Conventions
- Follow Rails 8 conventions strictly
- Use Hotwire/Turbo for all real-time updates
- Stimulus for client-side interactions only
- No React, Vue, or other JavaScript frameworks
- GraphQL for API layer

### Obra Superpowers Workflows
- **BRAINSTORM → PLAN → EXECUTE** - Never skip phases
- Use `superpowers:brainstorming` for all new features
- Use `superpowers:writing-plans` after design validation
- Use `superpowers:executing-plans` for implementation
- Use `superpowers:verification-before-completion` before marking tasks done

---

## 3. Technical Stack

### Backend
- **Ruby** 3.3+
- **Rails** 8.0
- **PostgreSQL** 16+ with JSONB for flexible schemas
- **Solid Queue** for background job processing (Rails 8 built-in)
- **GraphQL** via graphql-ruby gem

### Frontend
- **Hotwire** (Turbo + Stimulus) for real-time updates
- **Tailwind CSS** 3+ for styling
- **ViewComponent** for reusable UI components
- **ERB templates** (no separate frontend framework)

### Chess Engine
- **Stockfish** 16+ for opponent AI
- **chess-rb** or similar gem for move validation
- **FEN notation** for board state serialization
- **SAN notation** for move recording

### LLM Integration (Model-Agnostic)
- **Design principle**: Support any OpenAI-compatible API
- **Default**: GPT-3.5-turbo (cost-effective for MVP)
- **Supported providers**:
  - OpenAI (GPT-3.5, GPT-4)
  - Anthropic Claude (via OpenAI-compatible wrapper)
  - Local models (Ollama, llama.cpp)
  - Azure OpenAI
  - Any OpenAI-compatible endpoint
- **Client library**: ruby-openai gem
- **API keys**: User-provided, encrypted at rest, session-based storage

### Deployment (Heroku)
- **Platform**: Heroku
- **Addons**:
  - heroku-postgresql (hobby-dev → basic)
  - heroku-redis (for Action Cable/Turbo Streams)
  - Optional: papertrail/logdna for logging
- **Buildpacks**:
  - heroku/ruby (primary)
  - Custom buildpack for Stockfish binary

---

## 4. Development Workflow (MANDATORY SEQUENCE)

### Phase 1: BRAINSTORM
- **Tool**: `superpowers:brainstorming` skill
- **Purpose**: Refine rough ideas into fully-formed designs
- **Process**:
  - Check current project state (files, docs, commits)
  - Ask clarifying questions one at a time
  - Explore 2-3 approaches with trade-offs
  - Document edge cases and failure modes
  - Present design in 200-300 word sections
  - Validate each section before continuing
- **Output**: Design document in `docs/plans/YYYY-MM-DD-<topic>-design.md`

### Phase 2: WRITE PLAN
- **Tool**: `superpowers:writing-plans` skill
- **Purpose**: Create detailed implementation tasks
- **Process**:
  - Break design into bite-sized tasks
  - Include exact file paths and code examples
  - Specify test cases for each task
  - Assume implementer has zero codebase context
  - Number all tasks for tracking
- **Output**: Implementation plan in `docs/plans/YYYY-MM-DD-<topic>-plan.md`

### Phase 3: EXECUTE PLAN
- **Tool**: `superpowers:executing-plans` skill
- **Purpose**: Implement in controlled batches with review checkpoints
- **Process**:
  - Execute tasks in small batches
  - TDD mandatory: failing test first, then implementation
  - Use `superpowers:test-driven-development` for each task
  - Commit after each completed task
  - Use `superpowers:verification-before-completion` before marking done
  - Review between batches
- **Output**: Working code with full test coverage

### Critical Rules
- **Never skip phases** - Specific instructions describe WHAT to build, not permission to skip HOW
- **One task at a time** - Complete current task before starting next
- **Red → Green → Refactor** - Always start with failing test
- **Commit frequently** - One logical change per commit

---

## 5. Specialized Development Agent Contexts

Each specialized agent has a dedicated context file in `docs/agents/`:

### Architecture Agent
**File**: `docs/agents/architecture-context.md`
**Responsibilities**:
- System design principles and patterns
- Database schema decisions: PostgreSQL + JSONB
- Service boundaries: MatchRunner, AgentOrchestrator, MoveValidator
- Background job architecture using Solid Queue
- Caching strategy and performance
- API design patterns and GraphQL schema organization

### GraphQL Specialist
**File**: `docs/agents/graphql-context.md`
**Responsibilities**:
- Schema design for chess domain
- Type definitions: Match, Agent, Move, BoardState
- Mutation patterns: createMatch, submitMove, updateAgent
- Query optimization and N+1 prevention
- Error handling and validation patterns
- Resolver organization

### Rails Specialist
**File**: `docs/agents/rails-context.md`
**Responsibilities**:
- Rails 8 conventions and best practices
- Controller organization and RESTful patterns
- Hotwire integration: Turbo Frames, Turbo Streams
- Stimulus controller patterns for interactivity
- ActiveRecord optimizations and query patterns
- Session management without user accounts

### Testing Specialist
**File**: `docs/agents/testing-context.md`
**Responsibilities**:
- RSpec best practices and organization
- FactoryBot factory design for chess domain
- VCR cassettes for LLM API mocking
- System test patterns with Capybara
- Test data builders for complex board states
- Coverage requirements and CI integration

### Reviewer Agent
**File**: `docs/agents/reviewer-context.md`
**Responsibilities**:
- Code quality checklist and review criteria
- Test coverage verification (minimum 90%)
- Security audit: SQL injection, XSS, API key exposure
- Performance considerations: N+1 queries, background jobs
- Rails convention compliance
- Documentation completeness

---

## 6. Implementation Phases (ADAPTIVE)

### Adaptive Planning Principle
**We will revisit and revise remaining phases after completing each one.**

- Complete one phase fully (design → plan → implement → test → review)
- Reflect on what we learned
- Revise subsequent phases based on new insights
- Update this context.md with decisions made
- **Only the current phase plan is authoritative**

### Between-Phase Review Questions
- What worked well? What was harder than expected?
- Are there architectural changes we should make now?
- Should we reorder remaining phases?
- Do we need to add or remove phases?
- What dependencies or blockers did we discover?

---

### Phase 1: Rails Setup + GraphQL Foundation
**Status**: ✅ Complete (2025-11-05)
**Goal**: Working Rails 8 app with GraphQL API and testing infrastructure

**Tasks**:
- Initialize Rails 8 app with PostgreSQL
- Configure Tailwind CSS and Hotwire
- Set up GraphQL with graphql-ruby
- Configure Solid Queue for background jobs
- Set up RSpec, FactoryBot, VCR
- Create basic GraphQL schema and playground

**Completion Criteria**:
- ✅ `rails server` runs successfully
- ✅ GraphQL playground accessible at `/graphiql`
- ✅ Test suite runs and passes (2 examples, 0 failures)
- ✅ Can create basic queries and mutations

**Completed**: 2025-11-05
**Final Commit**: f0bfd1b
**Learnings**:
- Rails 8 generation with --css=tailwind works smoothly
- Merging into existing directory requires careful rsync
- SimpleCov, VCR, FactoryBot configuration straightforward
- GraphQL generator creates clean structure
- Solid Queue install seamless with Rails 8
- Coverage threshold of 90% may need adjustment for minimal apps with lots of generated code

**After Completion**: Revise Phases 2-6 based on setup learnings

---

### Phase 2: Agent Model + Prompt Management (INITIAL PLAN)
**Status**: Not Started
**Note**: This will be revised after Phase 1 completion

**Initial Goals**:
- Create Agent model with prompt storage
- Build prompt editor interface
- Implement API key encryption
- Session-based key storage
- Support multiple LLM providers

**This phase will be fully specified after Phase 1 review.**

---

### Phases 3-6: High-Level Roadmap (SUBJECT TO CHANGE)

**Phase 3**: Chess Engine Integration
- Move validation, Stockfish integration, board state management

**Phase 4**: LLM Agent Orchestrator
- Parallel agent execution, decision strategies, prompt logging

**Phase 5**: Match Runner + Background Jobs
- Match state management, time control, retry logic

**Phase 6**: Real-time UI + Turbo Streams
- Match viewer, live board updates, move history

**These phases will be refined based on learnings from previous phases.**

---

## 7. Architecture Decisions

### Database Schema (Initial Design)

**`agents` table**
```ruby
# id, name, prompt_text, role, configuration (jsonb), created_at, updated_at
# role examples: 'opening', 'tactical', 'positional', 'endgame', 'general'
# configuration: { temperature: 0.7, max_tokens: 500, ... }
```

**`matches` table**
```ruby
# id, white_config (jsonb), black_config (jsonb), status, time_control (jsonb),
# decision_strategy, result, stockfish_level, created_at, updated_at
# white_config: { agent_ids: [1,2,3], strategy: 'majority_vote' }
# decision_strategy: 'majority_vote', 'weighted', 'hierarchical', 'debate', 'single'
# status: 'setup', 'in_progress', 'completed', 'abandoned'
```

**`moves` table**
```ruby
# id, match_id, move_number, color, san_notation, uci_notation, fen_after,
# thinking_logs (jsonb), time_taken, flagged, created_at
# thinking_logs: [{ agent_id: 1, prompt: '...', response: '...', suggested_move: 'e4' }]
```

**`board_states` table**
```ruby
# id, match_id, fen, move_count, halfmove_clock, fullmove_number, created_at
```

**`api_configurations` table**
```ruby
# id, session_id, provider, api_key_encrypted, model_name, base_url,
# parameters (jsonb), created_at, updated_at
# provider: 'openai', 'anthropic', 'ollama', 'custom'
```

### Service Architecture

**`AgentOrchestrator`**
- Manages agent execution based on decision strategy
- Coordinates parallel or sequential agent calls
- Collects agent responses and applies decision logic
- Logs all agent thinking for observability

**`LlmClient`**
- Model-agnostic wrapper for LLM API calls
- Handles authentication, retries, timeouts
- Supports OpenAI, Claude, Ollama, custom endpoints
- Normalizes responses across providers

**`MoveValidator`**
- Chess rule validation
- Legal move checking
- Checkmate/stalemate detection
- FEN and SAN notation parsing

**`StockfishEngine`**
- Interface to Stockfish binary
- Configurable difficulty levels
- Move generation and position evaluation
- UCI protocol communication

**Decision Strategy Services**:
- `MajorityVoteStrategy`: Simple voting (requires odd number of agents)
- `WeightedVoteStrategy`: Agents have different vote weights
- `HierarchicalStrategy`: Judge agent reviews suggestions
- `DebateStrategy`: Agents discuss before final decision
- `SingleAgentStrategy`: One agent decides (simplest)

**`MatchRunner` (Background Job)**
- Orchestrates full match execution
- Manages turn-by-turn progression
- Handles time control and flagging
- Broadcasts Turbo Stream updates

### Background Jobs (Solid Queue)

**`RunMatchJob`**
- Execute match turn-by-turn with time tracking
- Handle both player agents and Stockfish moves
- Broadcast real-time updates via Turbo Streams
- Mark match complete on checkmate/stalemate/timeout

**`AgentMoveJob`**
- Individual agent move generation (parallelizable)
- Timeout handling with configurable limits
- Retry logic for API failures
- Log all prompts and responses

**`CleanupExpiredSessionsJob`**
- Remove old API keys from sessions
- Clean up abandoned matches
- Archive completed match data

### API Design (GraphQL)

**Mutations**:
- `createMatch(whiteAgentIds: [ID!]!, blackAgentIds: [ID!]!, timeControl: TimeControlInput!, decisionStrategy: DecisionStrategy!)`
- `updateAgent(id: ID!, name: String, promptText: String, configuration: JSON)`
- `configureApi(provider: Provider!, apiKey: String!, modelName: String, baseUrl: String, parameters: JSON)`
- `deleteAgent(id: ID!)`

**Queries**:
- `match(id: ID!): Match`
- `matches(status: MatchStatus): [Match!]!`
- `agents: [Agent!]!`
- `agent(id: ID!): Agent`
- `moveHistory(matchId: ID!): [Move!]!`

**Types**:
```graphql
type Match {
  id: ID!
  status: MatchStatus!
  whiteConfig: PlayerConfig!
  blackConfig: PlayerConfig!
  timeControl: TimeControl!
  result: String
  moves: [Move!]!
  currentBoardState: BoardState!
}

type Agent {
  id: ID!
  name: String!
  role: String!
  promptText: String!
  configuration: JSON!
}

type Move {
  id: ID!
  moveNumber: Int!
  color: Color!
  sanNotation: String!
  fenAfter: String!
  thinkingLogs: [ThinkingLog!]!
  timeTaken: Float!
  flagged: Boolean!
}
```

**No subscriptions in MVP** - Turbo Streams handles real-time updates

---

## 8. Testing Strategy

### Test Organization
```
spec/
  models/          # Unit tests for Agent, Match, Move, BoardState
  services/        # Service object tests with mocked dependencies
  jobs/            # Background job tests with inline queue adapter
  requests/        # GraphQL API endpoint tests
  system/          # Full user flow tests with Capybara
  support/
    vcr_cassettes/ # Recorded LLM API responses
    factories/     # FactoryBot factories
    helpers/       # Shared test helpers
```

### RSpec Patterns
- Use `let` and `let!` for test data setup
- FactoryBot factories for all models: `create(:agent, role: :opening)`
- Descriptive context blocks: `context 'when agent times out'`
- One expectation per example when possible
- Use `aggregate_failures` for related assertions
- Use `travel_to` for time-dependent tests

### VCR for LLM Mocking
```ruby
# spec/support/vcr.rb
VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
end
```

**Cassette naming**: `spec/vcr_cassettes/agent_move_gpt35_opening.yml`
**Record once, replay for fast tests**
**Update cassettes when prompts change**

### Factory Design
```ruby
FactoryBot.define do
  factory :agent do
    name { "Tactical Master" }
    role { "tactical" }
    prompt_text { "You are a chess tactical genius..." }

    trait :opening do
      role { "opening" }
      prompt_text { "You specialize in chess openings..." }
    end

    trait :positional do
      role { "positional" }
      prompt_text { "You excel at positional play..." }
    end
  end

  factory :match do
    transient do
      white_agents { create_list(:agent, 3) }
      black_agents { create_list(:agent, 3) }
    end

    white_config { { agent_ids: white_agents.map(&:id), strategy: 'majority_vote' } }
    black_config { { agent_ids: black_agents.map(&:id), strategy: 'majority_vote' } }
    decision_strategy { 'majority_vote' }
    time_control { { initial_seconds: 600, increment_seconds: 5 } }
  end
end
```

### Coverage Requirements
- **Minimum 90% line coverage**
- **100% coverage for service objects and critical paths**
- SimpleCov report generated on every test run
- CI fails if coverage drops below threshold

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  minimum_coverage 90
  add_filter '/spec/'
  add_filter '/config/'
end
```

---

## 9. Deployment Configuration (Heroku)

### Heroku Addons
```bash
heroku addons:create heroku-postgresql:hobby-dev
heroku addons:create heroku-redis:mini
# Optional: heroku addons:create papertrail:choklad
```

### Environment Variables
```bash
heroku config:set RAILS_MASTER_KEY=<from config/master.key>
heroku config:set RAILS_ENV=production
heroku config:set RACK_ENV=production
heroku config:set RAILS_LOG_TO_STDOUT=enabled
heroku config:set RAILS_SERVE_STATIC_FILES=enabled
heroku config:set WEB_CONCURRENCY=2
heroku config:set RAILS_MAX_THREADS=5
```

### Procfile
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec solid_queue start
release: bundle exec rails db:migrate
```

### Buildpacks
```bash
heroku buildpacks:add heroku/ruby
# Add custom buildpack for Stockfish:
heroku buildpacks:add https://github.com/chess-org/heroku-buildpack-stockfish.git
```

### Database Configuration
```yaml
# config/database.yml
production:
  adapter: postgresql
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  prepared_statements: false
```

### Scaling Strategy
- **Start**: 1 web dyno (hobby), 1 worker dyno (hobby)
- **Monitor**: Job queue depth for worker scaling
- **Scale up**: `heroku ps:scale worker=2` if queue backs up
- **Database**: Upgrade to `mini` or `basic` if connection limits hit

### Stockfish Binary
- Install via custom buildpack during deployment
- Configure path in `config/initializers/stockfish.rb`
- Verify installation in release phase

---

## 10. Design Decisions Made

This section documents all decisions made during the initial brainstorming phase on 2025-11-04.

### Infrastructure & Deployment
- **Platform**: Heroku (simplicity, built-in Postgres, easy scaling)
- **Background Jobs**: Solid Queue (Rails 8 default, sufficient for move-based processing, one less service to manage)
- **Database**: PostgreSQL 16+ with JSONB for flexible schema evolution
- **Real-time**: Turbo Streams over Action Cable (no WebSocket fallback needed for MVP)

### Frontend & UI
- **CSS Framework**: Tailwind CSS (utility-first, pairs well with Hotwire)
- **JavaScript**: Hotwire/Turbo + Stimulus (no separate frontend framework)
- **Components**: ViewComponent for reusable UI elements

### LLM Integration
- **API Design**: Model-agnostic, support any OpenAI-compatible endpoint
- **Supported Providers**: OpenAI, Anthropic Claude, Ollama, local models, custom endpoints
- **Default Model**: GPT-3.5-turbo (cost-effective for MVP)
- **API Keys**: Session-based storage, encrypted at rest, user-provided (no accounts)

### Game Rules & Time Control
- **Time Constraints**: Yes - games have time controls (blitz, rapid, classical)
- **Optimization**: Players responsible for optimizing prompts for speed/cost trade-offs
- **Timeout Handling**: Keep retrying for valid moves, flag time violations
- **Move Validation**: Reject invalid moves, keep requesting until valid or time runs out

### Agent Orchestration (Flexible Design)
- **MVP Default**: 3 agents per player (Opening/Tactical/Positional) with majority voting
- **Experimentation Enabled**: Agent count, roles, and decision strategies are configurable per match
- **Decision Strategies**:
  - Simple majority voting (3+ agents)
  - Weighted voting (agents have different vote weights)
  - Hierarchical (one "judge" agent reviews others' suggestions)
  - Debate/consensus (agents discuss before deciding)
  - Single agent (simplest case)
- **Why**: Different strategies may excel at different game phases; enables research on meta-strategies

### Observability
- **Logging**: Full logging of all prompts, responses, and timing data
- **Storage**: Database (JSONB in `moves.thinking_logs`)
- **Purpose**: Learn what prompt strategies work best, debug agent behavior

### Development Philosophy
- **TDD**: Non-negotiable, every feature starts with failing test
- **Adaptive Planning**: Revise remaining phases after each phase completion
- **Obra Superpowers**: Use skills for all workflows (brainstorming, planning, execution, TDD, review)
- **Git Workflow**: Feature branches, PRs, conventional commits, never push to main

---

## 11. Open Questions (To Be Resolved During Implementation)

### Phase 1 Questions
- Which chess-rb gem is most maintained? Or use python-chess via system call?
- How to package Stockfish binary for Heroku deployment?
- GraphQL schema: Relay-style connections or simple arrays for MVP?
- ViewComponent: Install separate gem or use Rails 8 built-in?

### Phase 2+ Questions
- Should agent roles be predefined enum or free-text?
- How to version agent prompts for A/B testing?
- Session storage: Redis or database-backed sessions?
- How long to keep match history before archiving?

### Future Considerations (Post-MVP)
- Tournament bracket system
- ELO rating for agents
- Agent marketplace or sharing
- Multi-model comparisons (GPT-4 vs Claude head-to-head)
- Replay analysis with different agents
- Agent performance analytics dashboard

---

## 12. Getting Started

### For Developers Starting Work
1. Read this entire context.md file
2. Check current phase status in Section 6
3. If starting new phase, run `superpowers:brainstorming` to refine design
4. Use `superpowers:writing-plans` to create implementation plan
5. Use `superpowers:executing-plans` to implement with TDD
6. Use `superpowers:verification-before-completion` before marking done
7. Update this context.md with decisions made

### For Specialized Agents
1. Read this context.md file for overall project understanding
2. Read your specialized context file in `docs/agents/`
3. Follow your specialized guidelines while respecting core constraints
4. Use TDD for all implementation
5. Request code review via `superpowers:requesting-code-review` when done

### Critical Reminder
**Never skip the BRAINSTORM → PLAN → EXECUTE workflow.**
Specific instructions describe WHAT to build, not permission to skip HOW we build it.

---

## 13. Document Maintenance

### When to Update This Document
- After completing each implementation phase
- When making architectural decisions
- When answering open questions
- When changing core constraints (rare, requires discussion)
- When adding new specialized agent contexts

### Version History
- **2025-11-04**: Initial version created during brainstorming session
- Future updates will be logged here with date and summary

---

**This context.md is a living document. Update it as we learn and evolve the system.**
