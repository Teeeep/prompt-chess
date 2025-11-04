# Chess Prompt League MVP

Platform for prompt engineers to create LLM agents that play chess.

## Tech Stack

- Ruby 3.3+
- Rails 8.0.0
- PostgreSQL 16+
- Tailwind CSS (standalone CLI)
- Hotwire (Turbo + Stimulus)
- GraphQL
- Solid Queue (background jobs)

## Setup

### Prerequisites

- Ruby 3.3+
- PostgreSQL 16+
- Bundler

### Installation

```bash
# Clone the repository
git clone https://github.com/Teeeep/prompt-chess.git
cd prompt-chess

# Install dependencies
bundle install

# Set up environment variables
cp .env.example .env
# Edit .env and add your API keys

# Create and migrate database
rails db:create db:migrate

# Run tests
bundle exec rspec

# Start development server (Rails + Tailwind + Solid Queue)
bin/dev
```

### Verify Installation

1. Visit `http://localhost:3000` - Rails should be running
2. Visit `http://localhost:3000/graphiql` - GraphiQL playground
3. Run query `{ testField }` - should return "Hello from GraphQL!"
4. Run `bundle exec rspec` - all tests should pass

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/requests/graphql_spec.rb

# Run with coverage
bundle exec rspec
open coverage/index.html
```

### Development Workflow

See `context.md` for full development workflow including:
- BRAINSTORM → PLAN → EXECUTE process
- TDD requirements
- Git workflow (feature branches, conventional commits)
- Specialized agent contexts

## Project Context

See `context.md` for comprehensive project documentation.

Design documents and implementation plans in `docs/plans/`.

## Phase 1 Status

✅ Rails 8 setup complete
✅ GraphQL foundation working
✅ Testing infrastructure configured
✅ Solid Queue for background jobs
✅ Smoke tests passing

**Next:** Phase 2 - Agent Model + Prompt Management
