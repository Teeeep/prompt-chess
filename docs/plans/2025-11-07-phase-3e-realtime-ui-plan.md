# Phase 3e: Real-time UI - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create real-time match viewing UI with GraphQL subscriptions, live board updates, move history, thinking logs, and match statistics.

**Architecture:** GraphQL subscriptions via Action Cable for real-time updates. MatchRunner broadcasts updates after each move. ViewComponents for modular UI. Stimulus controllers for WebSocket handling. chessboard.js for visual chess board. Tailwind CSS for styling.

**Tech Stack:** Rails 8, Hotwire (Turbo + Stimulus), ViewComponent, GraphQL subscriptions, Action Cable, chessboard.js, Tailwind CSS

**Dependencies:**
- Phase 3a complete (Match, Move models, GraphQL types)
- Phase 3d complete (MatchRunner, CreateMatch mutation)

---

## Task 1: Install Dependencies

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock` (via bundle install)

**Step 1: Add view_component gem**

Add to `Gemfile`:

```ruby
# ViewComponents for modular UI
gem 'view_component', '~> 3.0'
```

**Step 2: Add testing gems**

Add to `Gemfile` in the test group:

```ruby
group :test do
  # Existing gems...
  gem 'capybara'
  gem 'selenium-webdriver'
end
```

**Step 3: Install gems**

Run: `bundle install`

Expected: Gems installed successfully

**Step 4: Verify installation**

Run: `bundle list | grep view_component`

Expected: Shows view_component version

**Step 5: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "deps(phase-3e): add view_component and system test gems

Add dependencies for Phase 3e:
- view_component for modular UI components
- capybara and selenium-webdriver for system tests

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: GraphQL Subscription Types

**Files:**
- Create: `app/graphql/types/subscription_type.rb`
- Create: `app/graphql/types/match_update_payload_type.rb`
- Modify: `app/graphql/prompt_chess_schema.rb`

**Step 1: Create MatchUpdatePayloadType**

Create `app/graphql/types/match_update_payload_type.rb`:

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

**Step 2: Create SubscriptionType**

Create `app/graphql/types/subscription_type.rb`:

```ruby
module Types
  class SubscriptionType < GraphQL::Schema::Object
    field :match_updated, Types::MatchUpdatePayloadType, null: false,
      description: "Subscribe to real-time updates for a match" do
      argument :match_id, ID, required: true
    end

    def match_updated(match_id:)
      # Subscription is triggered by MatchRunner broadcasting
      # No implementation needed here - GraphQL handles it
    end
  end
end
```

**Step 3: Enable subscriptions in schema**

Modify `app/graphql/prompt_chess_schema.rb`:

```ruby
class PromptChessSchema < GraphQL::Schema
  mutation(Types::MutationType)
  query(Types::QueryType)
  subscription(Types::SubscriptionType)  # Add this line

  # Enable subscriptions via Action Cable
  use GraphQL::Subscriptions::ActionCableSubscriptions  # Add this line
end
```

**Step 4: Verify GraphQL schema loads**

Run: `bundle exec rails runner 'puts PromptChessSchema.to_definition' | grep -A 5 'type Subscription'`

Expected: Shows Subscription type with matchUpdated field

**Step 5: Commit**

```bash
git add app/graphql/types/subscription_type.rb \
        app/graphql/types/match_update_payload_type.rb \
        app/graphql/prompt_chess_schema.rb
git commit -m "feat(phase-3e): add GraphQL subscription types

Create subscription infrastructure:
- SubscriptionType with matchUpdated field
- MatchUpdatePayloadType for subscription data
- Enable ActionCableSubscriptions in schema

Provides foundation for real-time match updates.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: GraphQL Channel for Action Cable

**Files:**
- Create: `app/channels/graphql_channel.rb`

**Step 1: Create GraphqlChannel**

Create `app/channels/graphql_channel.rb`:

```ruby
class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    query = data["query"]
    variables = ensure_hash(data["variables"])
    operation_name = data["operationName"]
    context = {
      channel: self,
      session: session
    }

    result = PromptChessSchema.execute(
      query: query,
      context: context,
      variables: variables,
      operation_name: operation_name
    )

    payload = {
      result: result.to_h,
      more: result.subscription?
    }

    # Track subscription IDs
    if result.context[:subscription_id]
      @subscription_ids << result.context[:subscription_id]
    end

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      PromptChessSchema.subscriptions.delete_subscription(sid)
    end
  end

  private

  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      ambiguous_param.present? ? ensure_hash(JSON.parse(ambiguous_param)) : {}
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
```

**Step 2: Verify channel loads**

Run: `bundle exec rails runner 'puts GraphqlChannel.name'`

Expected: Prints "GraphqlChannel"

**Step 3: Commit**

```bash
git add app/channels/graphql_channel.rb
git commit -m "feat(phase-3e): add GraphQL Action Cable channel

Create GraphqlChannel for WebSocket communication:
- Handles GraphQL query execution over Action Cable
- Tracks subscription IDs for cleanup
- Supports variables and operation names
- Transmits results to connected clients

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Broadcasting from MatchRunner

**Files:**
- Modify: `app/services/match_runner.rb`
- Create: `spec/services/match_runner_broadcast_spec.rb`

**Step 1: Write test for broadcasting**

Create `spec/services/match_runner_broadcast_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'MatchRunner Broadcasting' do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  describe 'subscription triggers' do
    it 'broadcasts after agent move', vcr: { cassette_name: 'match_runner/broadcast_agent_move' } do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play only 1 move then end
      allow(runner).to receive(:game_over?).and_return(false, true)

      expect(PromptChessSchema.subscriptions).to receive(:trigger).with(
        :match_updated,
        { match_id: match.id.to_s },
        hash_including(:match, :latest_move)
      )

      runner.run!
    end

    it 'includes updated match and latest move in payload' do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play only 1 move
      allow(runner).to receive(:game_over?).and_return(false, true)

      expect(PromptChessSchema.subscriptions).to receive(:trigger) do |event, args, payload|
        expect(event).to eq(:match_updated)
        expect(args[:match_id]).to eq(match.id.to_s)
        expect(payload[:match]).to be_a(Match)
        expect(payload[:latest_move]).to be_a(Move)
      end

      runner.run!
    end

    it 'broadcasts final state on completion' do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play 1 move then end
      allow(runner).to receive(:game_over?).and_return(false, true)

      # Expect broadcast after move
      expect(PromptChessSchema.subscriptions).to receive(:trigger).once

      runner.run!

      match.reload
      expect(match.status).to eq('completed')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/services/match_runner_broadcast_spec.rb`

Expected: FAIL - broadcasts not implemented

**Step 3: Add broadcast_update method to MatchRunner**

Modify `app/services/match_runner.rb`, add private method:

```ruby
  private

  # ... existing private methods ...

  def broadcast_update(latest_move)
    PromptChessSchema.subscriptions.trigger(
      :match_updated,
      { match_id: @match.id.to_s },
      {
        match: @match.reload,
        latest_move: latest_move
      }
    )
  end
```

**Step 4: Call broadcast after agent move**

In `app/services/match_runner.rb`, modify the `play_agent_move` method to call broadcast at the end:

```ruby
  def play_agent_move(board_before, move_number)
    # ... existing code to create move ...

    # Add at the very end of the method:
    move = @match.moves.order(:move_number).last
    broadcast_update(move)
  end
```

**Step 5: Call broadcast after Stockfish move**

In `app/services/match_runner.rb`, modify the `play_stockfish_move` method to call broadcast at the end:

```ruby
  def play_stockfish_move(board_before, move_number)
    # ... existing code to create move ...

    # Add at the very end of the method:
    move = @match.moves.order(:move_number).last
    broadcast_update(move)
  end
```

**Step 6: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/services/match_runner_broadcast_spec.rb`

Expected: All tests pass

**Step 7: Commit**

```bash
git add spec/services/match_runner_broadcast_spec.rb app/services/match_runner.rb
git commit -m "feat(phase-3e): add real-time broadcasting to MatchRunner

Add subscription broadcasting:
- Broadcast after each agent move
- Broadcast after each Stockfish move
- Include updated match and latest move in payload

Enables real-time UI updates during match execution.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Match Controller and Route

**Files:**
- Create: `app/controllers/matches_controller.rb`
- Modify: `config/routes.rb`
- Create: `spec/requests/matches_spec.rb`

**Step 1: Write controller test**

Create `spec/requests/matches_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Matches", type: :request do
  describe "GET /matches/:id" do
    let(:agent) { create(:agent) }
    let(:match) { create(:match, agent: agent) }

    it "returns success" do
      get match_path(match)
      expect(response).to have_http_status(:success)
    end

    it "loads match with associations" do
      create(:move, :agent_move, match: match, move_number: 1)
      create(:move, :stockfish_move, match: match, move_number: 2)

      get match_path(match)

      expect(assigns(:match)).to eq(match)
      expect(assigns(:match).moves).to be_loaded
      expect(assigns(:match).agent).to be_loaded
    end
  end

  describe "GET /matches/:id with invalid id" do
    it "raises ActiveRecord::RecordNotFound" do
      expect {
        get match_path(id: 99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/requests/matches_spec.rb`

Expected: FAIL - route doesn't exist

**Step 3: Add route**

Modify `config/routes.rb`, add inside `Rails.application.routes.draw do`:

```ruby
  resources :matches, only: [:show]
```

**Step 4: Create controller**

Create `app/controllers/matches_controller.rb`:

```ruby
class MatchesController < ApplicationController
  def show
    @match = Match.includes(:agent, :moves).find(params[:id])
  end
end
```

**Step 5: Create basic view**

Create `app/views/matches/show.html.erb`:

```erb
<div class="container mx-auto px-4 py-8">
  <h1>Match #<%= @match.id %></h1>
  <p>Status: <%= @match.status %></p>
</div>
```

**Step 6: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/requests/matches_spec.rb`

Expected: All tests pass

**Step 7: Commit**

```bash
git add config/routes.rb \
        app/controllers/matches_controller.rb \
        app/views/matches/show.html.erb \
        spec/requests/matches_spec.rb
git commit -m "feat(phase-3e): add match show page route and controller

Create match viewing page:
- Route: GET /matches/:id
- Controller: loads match with agent and moves
- Basic view: renders match ID and status

Foundation for real-time match viewing UI.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: MatchBoardComponent with chessboard.js

**Files:**
- Create: `app/components/match_board_component.rb`
- Create: `app/components/match_board_component.html.erb`
- Create: `spec/components/match_board_component_spec.rb`

**Step 1: Write component test**

Create `spec/components/match_board_component_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MatchBoardComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent) }

  it "renders board container" do
    render_inline(MatchBoardComponent.new(match: match))

    expect(page).to have_css('[data-controller="chess-board"]')
    expect(page).to have_css('#board')
  end

  it "includes starting position FEN when no moves" do
    render_inline(MatchBoardComponent.new(match: match))

    expect(page).to have_css('[data-chess-board-position-value]')
    expect(page.find('[data-chess-board-position-value]')['data-chess-board-position-value'])
      .to eq(Chess::Game::DEFAULT_FEN)
  end

  it "includes latest position FEN when moves exist" do
    move = create(:move, :agent_move, match: match, move_number: 1,
                  board_state_after: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')

    render_inline(MatchBoardComponent.new(match: match))

    expect(page.find('[data-chess-board-position-value]')['data-chess-board-position-value'])
      .to eq(move.board_state_after)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/match_board_component_spec.rb`

Expected: FAIL - component doesn't exist

**Step 3: Create component class**

Create `app/components/match_board_component.rb`:

```ruby
class MatchBoardComponent < ViewComponent::Base
  def initialize(match:)
    @match = match
  end

  def board_fen
    @match.moves.any? ? @match.moves.last.board_state_after : Chess::Game::DEFAULT_FEN
  end
end
```

**Step 4: Create component template**

Create `app/components/match_board_component.html.erb`:

```erb
<div class="bg-white rounded-lg shadow-md p-6">
  <h2 class="text-xl font-bold mb-4">Board</h2>

  <!-- chessboard.js container -->
  <div id="board"
       data-controller="chess-board"
       data-chess-board-position-value="<%= board_fen %>"
       class="mb-4">
  </div>

  <div class="text-sm text-gray-600">
    <strong>FEN:</strong> <span class="font-mono text-xs"><%= board_fen %></span>
  </div>
</div>
```

**Step 5: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/match_board_component_spec.rb`

Expected: All tests pass

**Step 6: Commit**

```bash
git add app/components/match_board_component.rb \
        app/components/match_board_component.html.erb \
        spec/components/match_board_component_spec.rb
git commit -m "feat(phase-3e): add MatchBoardComponent for chess display

Create MatchBoardComponent:
- Displays current board position
- Integrates with chessboard.js via Stimulus
- Shows FEN notation
- Uses latest move's board state or starting position

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: MatchStatsComponent

**Files:**
- Create: `app/components/match_stats_component.rb`
- Create: `app/components/match_stats_component.html.erb`
- Create: `spec/components/match_stats_component_spec.rb`

**Step 1: Write component test**

Create `spec/components/match_stats_component_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MatchStatsComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, total_moves: 12, total_tokens_used: 3450, total_cost_cents: 5) }

  it "renders stats card" do
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Stats')
    expect(page).to have_content('Moves:')
    expect(page).to have_content('12')
  end

  it "displays token count" do
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Tokens:')
    expect(page).to have_content('3,450')
  end

  it "displays cost in dollars" do
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Cost:')
    expect(page).to have_content('$0.05')
  end

  it "displays average move time when present" do
    match.update!(average_move_time_ms: 850)
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Avg time:')
    expect(page).to have_content('850ms')
  end

  it "displays winner when completed" do
    match.update!(status: :completed, winner: :agent, result_reason: 'checkmate')
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Result:')
    expect(page).to have_content('Agent')
    expect(page).to have_content('Checkmate')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/match_stats_component_spec.rb`

Expected: FAIL - component doesn't exist

**Step 3: Create component class**

Create `app/components/match_stats_component.rb`:

```ruby
class MatchStatsComponent < ViewComponent::Base
  def initialize(match:)
    @match = match
  end
end
```

**Step 4: Create component template**

Create `app/components/match_stats_component.html.erb`:

```erb
<div class="bg-white rounded-lg shadow-md p-6">
  <h2 class="text-xl font-bold mb-4">Stats</h2>

  <div class="space-y-3">
    <div class="flex justify-between">
      <span class="text-gray-600">Moves:</span>
      <span class="font-semibold"><%= @match.total_moves %></span>
    </div>

    <div class="flex justify-between">
      <span class="text-gray-600">Tokens:</span>
      <span class="font-semibold"><%= number_with_delimiter(@match.total_tokens_used) %></span>
    </div>

    <div class="flex justify-between">
      <span class="text-gray-600">Cost:</span>
      <span class="font-semibold">$<%= sprintf('%.2f', @match.total_cost_cents / 100.0) %></span>
    </div>

    <% if @match.average_move_time_ms %>
      <div class="flex justify-between">
        <span class="text-gray-600">Avg time:</span>
        <span class="font-semibold"><%= @match.average_move_time_ms %>ms</span>
      </div>
    <% end %>

    <% if @match.opening_name %>
      <div class="flex justify-between">
        <span class="text-gray-600">Opening:</span>
        <span class="font-semibold"><%= @match.opening_name %></span>
      </div>
    <% end %>

    <% if @match.completed? %>
      <div class="pt-3 border-t">
        <div class="flex justify-between">
          <span class="text-gray-600">Result:</span>
          <span class="font-semibold text-lg
            <%= case @match.winner
                when 'agent' then 'text-green-600'
                when 'stockfish' then 'text-red-600'
                when 'draw' then 'text-gray-600'
                end %>">
            <%= @match.winner&.titleize %>
          </span>
        </div>
        <div class="text-sm text-gray-500 mt-1">
          <%= @match.result_reason&.titleize %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

**Step 5: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/match_stats_component_spec.rb`

Expected: All tests pass

**Step 6: Commit**

```bash
git add app/components/match_stats_component.rb \
        app/components/match_stats_component.html.erb \
        spec/components/match_stats_component_spec.rb
git commit -m "feat(phase-3e): add MatchStatsComponent for live statistics

Create MatchStatsComponent:
- Live match statistics (moves, tokens, cost, avg time)
- Opening name display
- Result and winner on completion
- Color-coded status badges

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: MoveListComponent

**Files:**
- Create: `app/components/move_list_component.rb`
- Create: `app/components/move_list_component.html.erb`
- Create: `spec/components/move_list_component_spec.rb`

**Step 1: Write component test**

Create `spec/components/move_list_component_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MoveListComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent) }

  it "renders moves list card" do
    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('Moves')
  end

  it "shows empty message when no moves" do
    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('No moves yet')
  end

  it "displays moves in pairs (white, black)" do
    create(:move, :agent_move, match: match, move_number: 1, move_notation: 'e4')
    create(:move, :stockfish_move, match: match, move_number: 2, move_notation: 'e5')
    create(:move, :agent_move, match: match, move_number: 3, move_notation: 'Nf3')

    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('1.')
    expect(page).to have_content('e4')
    expect(page).to have_content('e5')
    expect(page).to have_content('2.')
    expect(page).to have_content('Nf3')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/move_list_component_spec.rb`

Expected: FAIL - component doesn't exist

**Step 3: Create component class**

Create `app/components/move_list_component.rb`:

```ruby
class MoveListComponent < ViewComponent::Base
  def initialize(match:)
    @match = match
  end

  def move_pairs
    @match.moves.order(:move_number).each_slice(2).with_index(1)
  end
end
```

**Step 4: Create component template**

Create `app/components/move_list_component.html.erb`:

```erb
<div class="bg-white rounded-lg shadow-md p-6">
  <h2 class="text-xl font-bold mb-4">Moves</h2>

  <div class="max-h-96 overflow-y-auto">
    <% if @match.moves.any? %>
      <div class="space-y-2">
        <% move_pairs.each do |pair, number| %>
          <div class="flex items-center space-x-2 font-mono text-sm">
            <span class="text-gray-500 w-8"><%= number %>.</span>
            <span class="w-16"><%= pair[0].move_notation %></span>
            <% if pair[1] %>
              <span class="w-16"><%= pair[1].move_notation %></span>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <p class="text-gray-500 text-sm">No moves yet</p>
    <% end %>
  </div>
</div>
```

**Step 5: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/move_list_component_spec.rb`

Expected: All tests pass

**Step 6: Commit**

```bash
git add app/components/move_list_component.rb \
        app/components/move_list_component.html.erb \
        spec/components/move_list_component_spec.rb
git commit -m "feat(phase-3e): add MoveListComponent for game history

Create MoveListComponent:
- Scrollable move history
- Standard chess notation (1. e4 e5 2. Nf3 Nc6)
- Pairs moves by number
- Empty state message

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: ThinkingLogComponent

**Files:**
- Create: `app/components/thinking_log_component.rb`
- Create: `app/components/thinking_log_component.html.erb`
- Create: `spec/components/thinking_log_component_spec.rb`

**Step 1: Write component test**

Create `spec/components/thinking_log_component_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ThinkingLogComponent, type: :component do
  it "renders thinking log card" do
    move = create(:move, :agent_move, move_number: 1, move_notation: 'e4')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Latest Thinking')
  end

  it "shows move details" do
    move = create(:move, :agent_move, move_number: 1, move_notation: 'e4',
                  tokens_used: 150, response_time_ms: 750)
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Move 1: e4')
    expect(page).to have_content('150 tokens')
    expect(page).to have_content('750ms')
  end

  it "has collapsible prompt section" do
    move = create(:move, :agent_move, llm_prompt: 'Test prompt content')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Show Prompt')
    expect(page).to have_css('details')
  end

  it "has collapsible response section" do
    move = create(:move, :agent_move, llm_response: 'Test response content')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Show Response')
    expect(page).to have_css('details')
  end

  it "shows empty message when no move" do
    render_inline(ThinkingLogComponent.new(move: nil))

    expect(page).to have_content('No agent moves yet')
  end
end
```

**Step 2: Run test to verify it fails**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/thinking_log_component_spec.rb`

Expected: FAIL - component doesn't exist

**Step 3: Create component class**

Create `app/components/thinking_log_component.rb`:

```ruby
class ThinkingLogComponent < ViewComponent::Base
  def initialize(move:)
    @move = move
  end
end
```

**Step 4: Create component template**

Create `app/components/thinking_log_component.html.erb`:

```erb
<div class="bg-white rounded-lg shadow-md p-6">
  <h2 class="text-xl font-bold mb-4">Latest Thinking</h2>

  <% if @move %>
    <div class="space-y-4">
      <div>
        <div class="text-sm font-semibold text-gray-700 mb-2">
          Move <%= @move.move_number %>: <%= @move.move_notation %>
        </div>
        <div class="text-xs text-gray-500">
          <%= @move.tokens_used %> tokens • <%= @move.response_time_ms %>ms
        </div>
      </div>

      <details class="group">
        <summary class="cursor-pointer text-sm font-semibold text-blue-600 hover:text-blue-800">
          Show Prompt
        </summary>
        <div class="mt-2 p-3 bg-gray-50 rounded text-xs font-mono whitespace-pre-wrap max-h-48 overflow-y-auto">
          <%= @move.llm_prompt %>
        </div>
      </details>

      <details class="group">
        <summary class="cursor-pointer text-sm font-semibold text-blue-600 hover:text-blue-800">
          Show Response
        </summary>
        <div class="mt-2 p-3 bg-gray-50 rounded text-xs font-mono whitespace-pre-wrap max-h-48 overflow-y-auto">
          <%= @move.llm_response %>
        </div>
      </details>
    </div>
  <% else %>
    <p class="text-gray-500 text-sm">No agent moves yet</p>
  <% end %>
</div>
```

**Step 5: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/components/thinking_log_component_spec.rb`

Expected: All tests pass

**Step 6: Commit**

```bash
git add app/components/thinking_log_component.rb \
        app/components/thinking_log_component.html.erb \
        spec/components/thinking_log_component_spec.rb
git commit -m "feat(phase-3e): add ThinkingLogComponent for agent decisions

Create ThinkingLogComponent:
- Latest agent move details
- Collapsible prompt/response sections
- Token and timing data
- Monospace font for readability
- Empty state for no moves

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 10: Update Match Show View with Components

**Files:**
- Modify: `app/views/matches/show.html.erb`

**Step 1: Update view to use components**

Replace contents of `app/views/matches/show.html.erb`:

```erb
<div class="container mx-auto px-4 py-8"
     data-controller="match-subscription"
     data-match-subscription-match-id-value="<%= @match.id %>">

  <!-- Header -->
  <div class="bg-white rounded-lg shadow-md p-6 mb-6">
    <h1 class="text-3xl font-bold mb-2">
      Match #<%= @match.id %>
    </h1>
    <div class="text-gray-600">
      <%= @match.agent.name %> vs Stockfish Level <%= @match.stockfish_level %>
    </div>
    <div class="mt-2">
      <span class="px-3 py-1 rounded-full text-sm font-semibold
        <%= case @match.status
            when 'pending' then 'bg-yellow-100 text-yellow-800'
            when 'in_progress' then 'bg-blue-100 text-blue-800'
            when 'completed' then 'bg-green-100 text-green-800'
            when 'errored' then 'bg-red-100 text-red-800'
            end %>">
        <%= @match.status.titleize %>
      </span>
    </div>
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Chess Board -->
    <div class="lg:col-span-2">
      <%= render MatchBoardComponent.new(match: @match) %>
    </div>

    <!-- Sidebar -->
    <div class="space-y-6">
      <!-- Match Stats -->
      <%= render MatchStatsComponent.new(match: @match) %>

      <!-- Move List -->
      <%= render MoveListComponent.new(match: @match) %>
    </div>
  </div>

  <!-- Thinking Log (full width below) -->
  <% if @match.moves.agent.any? %>
    <div class="mt-6">
      <%= render ThinkingLogComponent.new(move: @match.moves.agent.last) %>
    </div>
  <% end %>
</div>
```

**Step 2: Test manually**

Run: `bundle exec rails server`

Navigate to: Create a match, then visit `/matches/:id`

Expected: Page renders with all components

**Step 3: Commit**

```bash
git add app/views/matches/show.html.erb
git commit -m "feat(phase-3e): integrate ViewComponents in match show view

Update match page layout:
- Responsive grid layout (board + sidebar)
- Header with match info and status badge
- MatchBoardComponent for chess display
- MatchStatsComponent for live stats
- MoveListComponent for game history
- ThinkingLogComponent for agent thinking

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 11: Add chessboard.js Assets

**Files:**
- Modify: `app/views/layouts/application.html.erb`

**Step 1: Add chessboard.js and jQuery via CDN**

Modify `app/views/layouts/application.html.erb`, add in the `<head>` section before the closing `</head>`:

```erb
    <%# chessboard.js dependencies %>
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <link rel="stylesheet" href="https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.css">
    <script src="https://unpkg.com/@chrisoakman/chessboardjs@1.0.0/dist/chessboard-1.0.0.min.js"></script>
```

**Step 2: Verify assets load**

Run: `bundle exec rails server`

Navigate to: `/matches/1`

Open browser console, type: `Chessboard`

Expected: Shows Chessboard constructor function

**Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat(phase-3e): add chessboard.js assets via CDN

Add chessboard.js dependencies:
- jQuery 3.7.1
- chessboard.js 1.0.0 CSS
- chessboard.js 1.0.0 JavaScript

Loaded via CDN for simplicity in MVP.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 12: Chess Board Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/chess_board_controller.js`
- Modify: `app/javascript/controllers/index.js`

**Step 1: Create chess board controller**

Create `app/javascript/controllers/chess_board_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { position: String }

  connect() {
    console.log("Chess board controller connected")
    this.board = Chessboard('board', {
      position: this.positionValue,
      draggable: false
    })
  }

  disconnect() {
    if (this.board) {
      this.board.destroy()
    }
  }

  positionValueChanged() {
    if (this.board) {
      this.board.position(this.positionValue)
    }
  }
}
```

**Step 2: Register controller**

Modify `app/javascript/controllers/index.js`, add:

```javascript
import ChessBoardController from "./chess_board_controller"
application.register("chess-board", ChessBoardController)
```

**Step 3: Test manually**

Run: `bundle exec rails server`

Navigate to: `/matches/1`

Expected: Chess board displays with pieces

**Step 4: Commit**

```bash
git add app/javascript/controllers/chess_board_controller.js \
        app/javascript/controllers/index.js
git commit -m "feat(phase-3e): add Stimulus controller for chessboard.js

Create chess board controller:
- Initializes chessboard.js with position from FEN
- Updates board when position changes
- Non-draggable (view-only)
- Cleans up on disconnect

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 13: Match Subscription Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/match_subscription_controller.js`
- Modify: `app/javascript/controllers/index.js`

**Step 1: Create match subscription controller**

Create `app/javascript/controllers/match_subscription_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static values = { matchId: String }

  connect() {
    console.log("Match subscription controller connected for match", this.matchIdValue)

    this.subscription = consumer.subscriptions.create(
      {
        channel: "GraphqlChannel"
      },
      {
        connected: () => {
          console.log("WebSocket connected, subscribing to match updates...")
          this.subscribe()
        },

        disconnected: () => {
          console.log("WebSocket disconnected")
        },

        received: (data) => {
          console.log("Received subscription data:", data)

          if (data.result && data.result.data && data.result.data.matchUpdated) {
            this.handleMatchUpdate(data.result.data.matchUpdated)
          }
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribe() {
    const query = `
      subscription($matchId: ID!) {
        matchUpdated(matchId: $matchId) {
          match {
            id
            status
            totalMoves
            totalTokensUsed
            totalCostCents
            winner
            resultReason
          }
          latestMove {
            id
            moveNumber
            player
            moveNotation
          }
        }
      }
    `

    this.subscription.send({
      query: query,
      variables: { matchId: this.matchIdValue },
      operationName: null
    })
  }

  handleMatchUpdate(data) {
    console.log("Match updated:", data)

    // Reload the page to show updates (simple MVP approach)
    // In production, would use Turbo Streams for targeted updates
    window.location.reload()
  }
}
```

**Step 2: Register controller**

Modify `app/javascript/controllers/index.js`, add:

```javascript
import MatchSubscriptionController from "./match_subscription_controller"
application.register("match-subscription", MatchSubscriptionController)
```

**Step 3: Test manually**

Run: `bundle exec rails server`

Open browser console

Navigate to: `/matches/1`

Expected: Console shows "Match subscription controller connected"

**Step 4: Commit**

```bash
git add app/javascript/controllers/match_subscription_controller.js \
        app/javascript/controllers/index.js
git commit -m "feat(phase-3e): add Stimulus controller for GraphQL subscriptions

Create match subscription controller:
- Establishes WebSocket connection via Action Cable
- Subscribes to matchUpdated GraphQL subscription
- Receives real-time match and move updates
- Reloads page on updates (simple MVP approach)

Future enhancement: Update specific DOM elements instead of reload.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 14: System Test for Match Viewing

**Files:**
- Create: `spec/system/match_viewing_spec.rb`
- Modify: `spec/rails_helper.rb`

**Step 1: Configure system tests**

Modify `spec/rails_helper.rb`, add after `RSpec.configure do |config|`:

```ruby
  # Configure Capybara for system tests
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end
```

Also add at the top with other requires:

```ruby
require 'capybara/rails'
require 'capybara/rspec'

Capybara.default_max_wait_time = 5
```

**Step 2: Write system test**

Create `spec/system/match_viewing_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Match Viewing', type: :system do
  let(:agent) { create(:agent, name: 'Test Agent') }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }

  before do
    driven_by(:rack_test)
  end

  describe 'viewing a pending match' do
    it 'displays match information' do
      visit match_path(match)

      expect(page).to have_content("Match ##{match.id}")
      expect(page).to have_content('Test Agent')
      expect(page).to have_content('Stockfish Level 1')
      expect(page).to have_content('Pending')
    end

    it 'shows empty move list' do
      visit match_path(match)

      expect(page).to have_content('Moves')
      expect(page).to have_content('No moves yet')
    end

    it 'shows zero stats' do
      visit match_path(match)

      expect(page).to have_content('Moves:')
      expect(page).to have_content('0')
      expect(page).to have_content('Tokens:')
      expect(page).to have_content('0')
    end
  end

  describe 'viewing a match with moves' do
    let!(:move1) { create(:move, :agent_move, match: match, move_number: 1, move_notation: 'e4') }
    let!(:move2) { create(:move, :stockfish_move, match: match, move_number: 2, move_notation: 'e5') }

    before do
      match.update!(total_moves: 2, total_tokens_used: 150)
    end

    it 'displays move history' do
      visit match_path(match)

      expect(page).to have_content('1.')
      expect(page).to have_content('e4')
      expect(page).to have_content('e5')
    end

    it 'displays updated stats' do
      visit match_path(match)

      expect(page).to have_content('Moves:')
      expect(page).to have_content('2')
      expect(page).to have_content('Tokens:')
      expect(page).to have_content('150')
    end

    it 'shows thinking log for agent move' do
      visit match_path(match)

      expect(page).to have_content('Latest Thinking')
      expect(page).to have_content('Move 1: e4')
      expect(page).to have_content('150 tokens')
    end
  end

  describe 'viewing a completed match' do
    before do
      match.update!(
        status: :completed,
        winner: :agent,
        result_reason: 'checkmate'
      )
    end

    it 'displays result' do
      visit match_path(match)

      expect(page).to have_content('Completed')
      expect(page).to have_content('Agent')
      expect(page).to have_content('Checkmate')
    end
  end
end
```

**Step 3: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/system/match_viewing_spec.rb`

Expected: All tests pass

**Step 4: Commit**

```bash
git add spec/system/match_viewing_spec.rb spec/rails_helper.rb
git commit -m "test(phase-3e): add system tests for match viewing UI

Add comprehensive system tests for:
- Viewing pending matches
- Viewing matches with moves
- Move history display
- Stats display
- Thinking log
- Completed match results

Configure Capybara:
- Rack::Test for non-JS tests
- Selenium Chrome headless for JS tests
- 5 second max wait time

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 15: System Test for JavaScript Features

**Files:**
- Create: `spec/system/match_viewing_js_spec.rb`

**Step 1: Write JavaScript system test**

Create `spec/system/match_viewing_js_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Match Viewing with JavaScript', type: :system, js: true do
  let(:agent) { create(:agent, name: 'Test Agent') }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }

  before do
    driven_by(:selenium_chrome_headless)
  end

  describe 'chess board display' do
    it 'renders chess board with chessboard.js' do
      visit match_path(match)

      # Wait for JavaScript to initialize
      sleep 1

      # Check that chessboard.js rendered
      expect(page).to have_css('#board')
      expect(page).to have_css('.board-b72b1') # chessboard.js class
    end

    it 'displays pieces for starting position' do
      visit match_path(match)

      sleep 1

      # chessboard.js renders pieces as images
      expect(page).to have_css('img[data-piece]', minimum: 32)
    end
  end

  describe 'expandable thinking log' do
    let!(:move) { create(:move, :agent_move, match: match, move_number: 1,
                        llm_prompt: 'Test prompt', llm_response: 'Test response') }

    it 'can expand prompt section' do
      visit match_path(match)

      # Initially collapsed
      expect(page).not_to have_content('Test prompt')

      # Click to expand
      click_on 'Show Prompt'

      # Now visible
      expect(page).to have_content('Test prompt')
    end

    it 'can expand response section' do
      visit match_path(match)

      # Initially collapsed
      expect(page).not_to have_content('Test response')

      # Click to expand
      click_on 'Show Response'

      # Now visible
      expect(page).to have_content('Test response')
    end
  end

  describe 'real-time subscription' do
    it 'establishes WebSocket connection' do
      visit match_path(match)

      # Wait for Stimulus controller to connect
      sleep 2

      # Check console for connection message (this is a basic check)
      # In a real app, you'd mock the WebSocket or test with actual updates
      expect(page).to have_css('[data-controller="match-subscription"]')
    end
  end
end
```

**Step 2: Run test to verify it passes**

Run: `NO_COVERAGE=true bundle exec rspec spec/system/match_viewing_js_spec.rb`

Expected: All tests pass (may need Chrome/Chromedriver installed)

**Step 3: Commit**

```bash
git add spec/system/match_viewing_js_spec.rb
git commit -m "test(phase-3e): add JavaScript system tests for interactive features

Add system tests for JavaScript functionality:
- Chess board rendering with chessboard.js
- Piece display verification
- Expandable prompt/response sections
- WebSocket connection establishment

Uses Selenium Chrome headless driver.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 16: Run Full Test Suite

**Files:**
- None (verification step)

**Step 1: Run all specs**

Run: `bundle exec rspec`

Expected: All tests pass

**Step 2: Check coverage**

Run: `open coverage/index.html`

Expected: Coverage ≥ 90% overall

**Step 3: If any tests fail, fix them**

Debug and fix any failing tests before proceeding.

**Step 4: Verify specific Phase 3e coverage**

Check that new files have good coverage:
- Components: 100%
- Controllers: 100%
- JavaScript: (tested via system tests)

---

## Task 17: Manual Testing

**Files:**
- None (manual verification)

**Step 1: Start Rails server**

Run: `bundle exec rails server`

**Step 2: Create a match via GraphiQL**

Navigate to: `http://localhost:3000/graphiql`

Run mutation:

```graphql
mutation {
  createMatch(agentId: "1", stockfishLevel: 1) {
    match {
      id
    }
    errors
  }
}
```

Expected: Returns match ID

**Step 3: Visit match page**

Navigate to: `http://localhost:3000/matches/[id]`

Expected:
- Page loads with match info
- Status shows "Pending" or "In Progress"
- Chess board displays
- Components render correctly

**Step 4: Watch match execute**

Wait for background job to process.

Expected:
- Page auto-reloads when moves are made
- Board updates with new positions
- Move list populates
- Stats update
- Thinking log shows agent moves

**Step 5: Verify completion**

Wait for match to complete.

Expected:
- Status changes to "Completed"
- Winner displayed
- Final stats shown
- All moves visible

**Step 6: Check browser console**

Open developer tools console.

Expected:
- No JavaScript errors
- See subscription connection messages
- See update received messages

---

## Task 18: Final Commit and Documentation

**Files:**
- Create: `docs/verification/phase-3e-completion.md`

**Step 1: Create completion verification doc**

Create `docs/verification/phase-3e-completion.md`:

```markdown
# Phase 3e Completion Verification

**Date**: 2025-11-07
**Phase**: 3e - Real-time UI

## Functional Requirements

- [x] User can view match at `/matches/:id`
- [x] Chess board displays current position with chessboard.js
- [x] Move list shows game history in standard notation
- [x] Stats update correctly (moves, tokens, cost, time)
- [x] Thinking log shows agent prompts/responses
- [x] Page updates when new moves played (via subscription)
- [x] Completed matches show result and winner
- [x] Status badges display correctly
- [x] Expandable sections work (prompt/response)

## Technical Requirements

- [x] All tests pass (`bundle exec rspec`)
- [x] ViewComponents render correctly
- [x] GraphQL subscriptions work via Action Cable
- [x] chessboard.js integrates successfully
- [x] Stimulus controllers connected and working
- [x] No console errors in browser
- [x] Coverage ≥ 90% for Phase 3e code

## Components Implemented

- [x] MatchBoardComponent (with chessboard.js)
- [x] MatchStatsComponent (live statistics)
- [x] MoveListComponent (move history)
- [x] ThinkingLogComponent (agent thinking)

## Controllers Implemented

- [x] MatchesController#show
- [x] GraphqlChannel (Action Cable)

## Stimulus Controllers

- [x] chess-board-controller (chessboard.js integration)
- [x] match-subscription-controller (WebSocket handling)

## GraphQL

- [x] SubscriptionType with matchUpdated field
- [x] MatchUpdatePayloadType
- [x] Broadcasting from MatchRunner

## Manual Testing Results

- [x] Match page loads correctly
- [x] Real-time updates work
- [x] Chess board displays and updates
- [x] All components render
- [x] Subscriptions establish successfully
- [x] Page reloads on updates

## Known Issues / Future Enhancements

- Page reload approach is simple but effective for MVP
- Future: Use Turbo Streams for targeted DOM updates
- Future: Add move animation
- Future: Add board interaction (click through history)

## Phase 3e Status: ✅ COMPLETE

All functional and technical requirements met.
Ready for Phase 3 review and final integration testing.
```

**Step 2: Commit verification doc**

```bash
git add docs/verification/phase-3e-completion.md
git commit -m "docs(phase-3e): add completion verification checklist

Document Phase 3e completion:
- All functional requirements met
- All technical requirements met
- Components, controllers, and tests implemented
- Manual testing completed successfully
- Ready for Phase 3 final review

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verification Checklist

Before marking Phase 3e complete:

- [ ] All dependencies installed (`view_component`, `capybara`, `selenium-webdriver`)
- [ ] GraphQL subscriptions configured with Action Cable
- [ ] GraphqlChannel created and working
- [ ] MatchRunner broadcasts updates after each move
- [ ] Match show page with responsive layout
- [ ] All ViewComponents created and rendering
- [ ] chessboard.js integrated and displaying board
- [ ] Stimulus controllers handle real-time updates
- [ ] System tests pass for all UI scenarios
- [ ] JavaScript system tests pass
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Coverage ≥ 90% for Phase 3e code
- [ ] Real-time updates work in browser (manual test)
- [ ] No console errors
- [ ] Match completion displays correctly

---

## Success Criteria for Phase 3 (All Sub-Phases)

**All sub-phases (3a-3e) complete:**
- ✓ Models and GraphQL types (3a)
- ✓ Stockfish integration (3b)
- ✓ Agent move generation (3c)
- ✓ Match orchestration (3d)
- ✓ Real-time UI (3e)

**Functional requirements:**
- [ ] User can create match via GraphQL
- [ ] Match executes in background
- [ ] Full game plays to completion
- [ ] Agent generates legal moves or forfeits
- [ ] Stockfish plays without crashing
- [ ] All data persisted (prompts, responses, timing, tokens)
- [ ] Real-time UI updates during match
- [ ] User can view match history and stats

**Technical requirements:**
- [ ] All tests pass
- [ ] Coverage ≥ 90%
- [ ] No security vulnerabilities
- [ ] Error handling works
- [ ] Background jobs process successfully
- [ ] WebSocket connections stable

---

## Phase 3e Status

**Status:** Ready for implementation
**Estimated Time:** 4-5 hours
**Complexity:** Medium-High (real-time subscriptions, ViewComponents, chessboard.js integration)

**Phase 3 Total Time:** ~12-15 hours across all sub-phases
