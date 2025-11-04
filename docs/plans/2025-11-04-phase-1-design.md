# Phase 1: Rails Setup + GraphQL Foundation - Design Document

**Date**: 2025-11-04
**Phase**: 1 of 6
**Status**: Design Complete, Ready for Planning
**Branch**: `feature/phase-1-rails-setup`

---

## Overview

### Goal
Create a solid Rails 8 foundation with all infrastructure in place, configured with best practices, ready for feature development in Phase 2.

### Philosophy
- No features yet, pure infrastructure setup
- Everything configured correctly from the start
- Prove the stack works with a simple smoke test
- Follow Rails 8 conventions strictly

### Success Criteria
- `rails new` completed with all gems installed
- `bin/dev` starts Rails + Tailwind compilation + Solid Queue worker
- `/graphiql` playground accessible and responds to test query
- `bundle exec rspec` runs and passes with 100% coverage on smoke test
- Database migrations run cleanly
- SimpleCov report generated

---

## Technical Decisions

### Core Stack
- **Ruby**: 3.3+ (latest stable)
- **Rails**: 8.0.0 (latest stable)
- **Database**: PostgreSQL
- **CSS**: Tailwind CSS via standalone CLI (Rails 8 default)
- **JavaScript**: Importmap with Hotwire (Turbo + Stimulus)
- **Background Jobs**: Solid Queue (built into Rails 8)

### Testing Stack
- **Test Framework**: RSpec (not Minitest)
- **Factories**: FactoryBot
- **HTTP Mocking**: VCR + WebMock
- **Coverage**: SimpleCov (90% minimum threshold)
- **Test Data**: Faker

### API Layer
- **GraphQL**: graphql-ruby gem
- **Playground**: GraphiQL (development only)
- **Initial Scope**: Minimal scaffold with "hello world" query only

### Why These Choices
- **Rails 8.0.0**: Latest stable, includes Solid Queue, modern conventions
- **Standalone Tailwind**: Rails 8 recommended approach, works seamlessly with Hotwire
- **GraphQL minimal**: Infrastructure only, build actual schema in Phase 2
- **RSpec configured fully**: Set up testing foundation correctly from start to avoid friction later
- **Chess gem**: Well-maintained, actively developed, has FEN/SAN support built-in

---

## Rails App Initialization

### Generation Approach
Since we already have a `prompt-chess` directory with context.md and docs/, we'll:

1. Generate Rails app in temporary directory
2. Carefully merge generated files into existing directory
3. Preserve our existing context.md, docs/, .git/
4. Update .gitignore if needed

### Generation Command
```bash
rails new prompt-chess-temp \
  --database=postgresql \
  --skip-test \
  --css=tailwind \
  --javascript=importmap

# Then merge into existing directory
```

### Flags Explained
- `--database=postgresql` - Our chosen database for JSONB support
- `--skip-test` - Using RSpec instead of Minitest
- `--css=tailwind` - Sets up standalone Tailwind CLI with bin/dev
- `--javascript=importmap` - Rails 8 default, works perfectly with Hotwire

### Additional Gems to Add

**Gemfile additions**:
```ruby
group :development, :test do
  gem 'rspec-rails', '~> 6.1'
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.2'
end

group :test do
  gem 'vcr', '~> 6.2'
  gem 'webmock', '~> 3.19'
  gem 'simplecov', '~> 0.22', require: false
end

gem 'graphql', '~> 2.1'
gem 'chess', '~> 0.3' # For Phase 2+, add now for completeness
```

---

## Testing Infrastructure Configuration

### RSpec Installation
```bash
rails generate rspec:install
```

Creates:
- `spec/spec_helper.rb` - RSpec core configuration
- `spec/rails_helper.rb` - Rails-specific configuration
- `.rspec` - Command-line options

### SimpleCov Configuration

**In `spec/spec_helper.rb` (MUST BE FIRST)**:
```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  minimum_coverage 90
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/bin/'
end

# Rest of spec_helper configuration...
```

### VCR Configuration

**Create `spec/support/vcr.rb`**:
```ruby
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  c.allow_http_connections_when_no_cassette = false
end
```

**Enable support files in `spec/rails_helper.rb`**:
```ruby
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }
```

### FactoryBot Configuration

**In `spec/rails_helper.rb`**:
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Other configuration...
end
```

### RSpec Best Practices Configuration

**In `spec/spec_helper.rb`**:
```ruby
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect # Disable 'should' syntax
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end
```

---

## GraphQL Minimal Scaffold

### Installation
```bash
bundle add graphql
rails generate graphql:install
```

### Generated Structure
```
app/graphql/
├── prompt_chess_schema.rb          # Main schema file
├── types/
│   ├── base_object.rb             # Base type class
│   ├── base_field.rb              # Base field class
│   ├── base_enum.rb               # Base enum class
│   ├── base_input_object.rb       # Base input class
│   ├── base_interface.rb          # Base interface class
│   ├── base_union.rb              # Base union class
│   ├── query_type.rb              # Root query type
│   └── mutation_type.rb           # Root mutation type
└── mutations/
    └── base_mutation.rb           # Base mutation class

app/controllers/
└── graphql_controller.rb          # GraphQL endpoint

config/routes.rb                    # Adds /graphql route
```

### Minimal Test Query

**Modify `app/graphql/types/query_type.rb`**:
```ruby
module Types
  class QueryType < Types::BaseObject
    description "The query root of this schema"

    field :test_field, String, null: false,
      description: "A simple test query to verify GraphQL is working"

    def test_field
      "Hello from GraphQL!"
    end
  end
end
```

### GraphiQL Playground
- Automatically available in development at `/graphiql`
- Provides interactive query builder
- Shows schema documentation
- Auto-completion for queries
- Perfect for manual testing

### Test Query
```graphql
query {
  testField
}
```

**Expected Response**:
```json
{
  "data": {
    "testField": "Hello from GraphQL!"
  }
}
```

---

## Solid Queue Configuration

### Installation
```bash
rails solid_queue:install
```

Creates:
- `config/queue.yml` - Queue configuration file
- `db/queue_schema.rb` - Queue database schema
- Migration for queue tables

### Environment-Specific Configuration

**Development** (`config/environments/development.rb`):
```ruby
config.active_job.queue_adapter = :solid_queue
```

**Test** (`config/environments/test.rb`):
```ruby
config.active_job.queue_adapter = :test # Inline, synchronous
```

**Production** (`config/environments/production.rb`):
```ruby
config.active_job.queue_adapter = :solid_queue
```

### Procfile.dev

**Create/update `Procfile.dev`**:
```
web: bin/rails server -p 3000
css: bin/rails tailwindcss:watch
worker: bundle exec solid_queue start
```

This allows `bin/dev` to start all three processes simultaneously.

---

## Environment Variables Setup

### .env.example (Committed to Git)
```bash
# Database
DATABASE_URL=postgresql://localhost/prompt_chess_development

# LLM API Keys (get your own)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Application
RAILS_ENV=development
```

### .env (Git-Ignored, Local Only)
Copy from `.env.example` and add real API keys for local testing.

### .gitignore Verification
Ensure these lines exist:
```
.env
.env.local
.env.*.local
```

### Loading Environment Variables

**Add to Gemfile (development/test group)**:
```ruby
gem 'dotenv-rails', groups: [:development, :test]
```

This automatically loads `.env` in development and test environments.

---

## Database Setup

### Create Databases
```bash
rails db:create
```

Creates:
- `prompt_chess_development`
- `prompt_chess_test`

### Run Migrations
```bash
rails db:migrate
```

Runs:
- Any initial Rails migrations
- Solid Queue migrations (job tables)

### Verify Database Connection
```bash
rails db:migrate:status
```

Should show all migrations as "up".

---

## Smoke Test

### Purpose
Prove the entire stack works together:
- Rails server responds
- Database connection works
- GraphQL endpoint accessible
- Tests run and pass
- Coverage reporting works

### Test File: `spec/requests/graphql_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe 'GraphQL API', type: :request do
  describe 'POST /graphql' do
    it 'returns successful response for test field query' do
      post '/graphql', params: { query: '{ testField }' }

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json['data']).to be_present
      expect(json['data']['testField']).to eq('Hello from GraphQL!')
    end

    it 'returns error for invalid query' do
      post '/graphql', params: { query: '{ invalidField }' }

      expect(response).to have_http_status(:success) # GraphQL returns 200 even for errors

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
    end
  end
end
```

### Running the Test
```bash
bundle exec rspec
```

**Expected Output**:
```
GraphQL API
  POST /graphql
    returns successful response for test field query
    returns error for invalid query

Finished in 0.05 seconds (files took 1.2 seconds to load)
2 examples, 0 failures

Coverage report generated for RSpec to /prompt-chess/coverage
2 / 2 LOC (100.0%) covered.
```

---

## Verification Checklist

Before marking Phase 1 complete, verify ALL of these:

### Installation Verification
- [ ] `bundle install` completes successfully
- [ ] All gems installed without errors
- [ ] `rails -v` shows Rails 8.0.0
- [ ] `ruby -v` shows Ruby 3.3+

### Database Verification
- [ ] `rails db:create` creates both databases
- [ ] `rails db:migrate` runs without errors
- [ ] `rails db:migrate:status` shows all migrations "up"
- [ ] Can connect to PostgreSQL: `rails db`

### Server Verification
- [ ] `bin/dev` starts all three processes (web, css, worker)
- [ ] Navigate to `http://localhost:3000` - Rails default page loads
- [ ] No console errors in terminal
- [ ] Tailwind CSS compiles without errors

### GraphQL Verification
- [ ] Navigate to `http://localhost:3000/graphiql`
- [ ] GraphiQL playground interface loads
- [ ] Run query `{ testField }` - returns "Hello from GraphQL!"
- [ ] Schema documentation visible in right panel
- [ ] Auto-completion works when typing queries

### Testing Verification
- [ ] `bundle exec rspec` runs successfully
- [ ] All tests pass (2 examples, 0 failures)
- [ ] SimpleCov report generated
- [ ] Open `coverage/index.html` - shows 100% coverage
- [ ] No deprecation warnings in test output

### File Structure Verification
- [ ] `spec/` directory exists with proper structure
- [ ] `app/graphql/` directory exists
- [ ] `config/queue.yml` exists (Solid Queue)
- [ ] `Procfile.dev` exists
- [ ] `.env.example` exists
- [ ] `.env` exists (git-ignored)

### Git Verification
- [ ] All changes committed to `feature/phase-1-rails-setup` branch
- [ ] Conventional commit messages used
- [ ] No uncommitted changes
- [ ] Context.md and docs/ preserved correctly

---

## Deliverables

### 1. Working Rails Application
- Fully configured Rails 8 app
- All dependencies installed
- Development environment running via `bin/dev`

### 2. Testing Infrastructure
- RSpec configured with best practices
- FactoryBot integrated
- VCR configured for HTTP mocking
- SimpleCov tracking coverage (90% threshold)
- Smoke tests passing

### 3. GraphQL Foundation
- GraphQL gem installed and configured
- GraphiQL playground accessible
- Basic schema with test query
- Request specs for GraphQL endpoint

### 4. Background Job Infrastructure
- Solid Queue installed and configured
- Queue database tables migrated
- Worker process in Procfile.dev
- Ready for job implementation in future phases

### 5. Documentation
- This design document
- `.env.example` with clear instructions
- README updates (if needed)
- All decisions documented in context.md

### 6. Clean Git History
- Feature branch created
- Conventional commits throughout
- Design document committed
- Ready for implementation plan

---

## Next Steps

### Immediate
1. **Write Implementation Plan** - Use `superpowers:writing-plans` to create detailed task-by-task plan
2. **Execute Plan** - Use `superpowers:executing-plans` with TDD for each task
3. **Verify Completion** - Run through entire checklist before marking Phase 1 complete

### After Phase 1 Completion
1. **Review Session** - Answer between-phase review questions from context.md
2. **Revise Future Phases** - Update Phase 2-6 plans based on learnings
3. **Update context.md** - Document any decisions made during implementation
4. **Create Pull Request** - Merge Phase 1 into main branch
5. **Begin Phase 2** - Agent Model + Prompt Management

---

## Open Questions (To Resolve During Implementation)

1. Should we add `database_cleaner` gem or rely on transactional fixtures?
2. Do we need `pry-rails` for debugging in development?
3. Should we configure GitHub Actions CI now or wait until Phase 2?
4. Do we want `rubocop` for linting from the start?
5. Should `.env` be created automatically or require manual setup?

**Decision**: Address these as they come up during implementation. Don't over-engineer Phase 1.

---

## Risk Mitigation

### Potential Issues

**Issue**: Rails 8 is very new, might have undiscovered issues
**Mitigation**: Stick to well-documented features, avoid bleeding edge

**Issue**: Merging generated Rails app into existing directory could cause conflicts
**Mitigation**: Generate in temp dir, carefully review each file before copying

**Issue**: SimpleCov might fail on first run if no code executed
**Mitigation**: Smoke test ensures code is executed and coverage is measured

**Issue**: PostgreSQL not installed or running locally
**Mitigation**: Verify PostgreSQL installation before starting, add to README

**Issue**: Solid Queue might need additional configuration
**Mitigation**: Follow Rails 8 documentation exactly, test worker process in Procfile.dev

---

## Success Definition

**Phase 1 is complete when**:
- A developer can clone the repo
- Run `bundle install`
- Run `rails db:setup`
- Run `bin/dev`
- Run `bundle exec rspec`
- Everything works perfectly with zero errors

**And we can confidently say**: "The foundation is rock solid. Let's build features."

---

**Design Status**: ✅ Complete and Validated
**Next Step**: Create implementation plan using `superpowers:writing-plans`
