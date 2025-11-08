# Human vs Stockfish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable humans to play chess against Stockfish via text-based move submission to validate complete game flow before agent integration.

**Architecture:** GraphQL mutation accepts human moves, validates with chess gem, saves to DB, enqueues job for Stockfish response. Job broadcasts move via ActionCable. Frontend form submits moves and updates board on broadcasts. Temporary scaffolding uses dummy "Human Player" agent.

**Tech Stack:** Rails 8, GraphQL, ActionCable, chess gem, Stockfish, Stimulus.js, chessboard.js

---

## PR 1: Backend - Submit Move Mutation

### Task 1.1: Add SubmitMove GraphQL Mutation

**Files:**
- Create: `app/graphql/mutations/submit_move.rb`
- Create: `app/graphql/types/payloads/submit_move_payload.rb`
- Modify: `app/graphql/types/mutation_type.rb`
- Create: `spec/requests/graphql/mutations/submit_move_spec.rb`

**Step 1: Write the failing test**

Create `spec/requests/graphql/mutations/submit_move_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "SubmitMove mutation", type: :request do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, status: :in_progress) }

  let(:mutation) do
    <<~GQL
      mutation($matchId: ID!, $moveNotation: String!) {
        submitMove(matchId: $matchId, moveNotation: $moveNotation) {
          success
          move {
            id
            moveNotation
            player
          }
          error
        }
      }
    GQL
  end

  describe "valid move submission" do
    it "creates a move record" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "e4"
      }

      expect {
        post "/graphql", params: { query: mutation, variables: variables }
      }.to change(Move, :count).by(1)

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be true
      expect(data["move"]["moveNotation"]).to eq("e4")
      expect(data["move"]["player"]).to eq("agent")
      expect(data["error"]).to be_nil
    end
  end

  describe "invalid move notation" do
    it "returns error without creating move" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "z99"
      }

      expect {
        post "/graphql", params: { query: mutation, variables: variables }
      }.not_to change(Move, :count)

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["move"]).to be_nil
      expect(data["error"]).to include("Invalid move")
    end
  end

  describe "wrong turn" do
    let!(:last_move) { create(:move, :agent_move, match: match, move_number: 1) }

    it "returns error when it's not agent's turn" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "e4"
      }

      post "/graphql", params: { query: mutation, variables: variables }

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["error"]).to eq("Not your turn")
    end
  end

  describe "completed match" do
    let(:completed_match) { create(:match, agent: agent, status: :completed) }

    it "returns error for completed match" do
      variables = {
        matchId: completed_match.id.to_s,
        moveNotation: "e4"
      }

      post "/graphql", params: { query: mutation, variables: variables }

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["error"]).to eq("Match already completed")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/graphql/mutations/submit_move_spec.rb`
Expected: FAIL with "uninitialized constant Mutations::SubmitMove"

**Step 3: Create SubmitMovePayload type**

Create `app/graphql/types/payloads/submit_move_payload.rb`:

```ruby
module Types
  module Payloads
    class SubmitMovePayload < Types::BaseObject
      field :success, Boolean, null: false,
        description: "Whether the move submission was successful"
      field :move, Types::MoveType, null: true,
        description: "The created move if successful"
      field :error, String, null: true,
        description: "Error message if unsuccessful"
    end
  end
end
```

**Step 4: Create SubmitMove mutation**

Create `app/graphql/mutations/submit_move.rb`:

```ruby
module Mutations
  class SubmitMove < BaseMutation
    description "Submit a move for a match"

    argument :match_id, ID, required: true, description: "ID of the match"
    argument :move_notation, String, required: true, description: "Move in standard algebraic notation (e.g., 'e4')"

    field :success, Boolean, null: false
    field :move, Types::MoveType, null: true
    field :error, String, null: true

    def resolve(match_id:, move_notation:)
      match = Match.find(match_id)

      # Check if match is already completed
      if match.status_completed?
        return {
          success: false,
          move: nil,
          error: "Match already completed"
        }
      end

      # Check if it's the agent's turn
      last_move = match.moves.last
      if last_move&.player_agent?
        return {
          success: false,
          move: nil,
          error: "Not your turn"
        }
      end

      # Get current board state
      current_fen = last_move&.board_state_after || MoveValidator::STARTING_FEN

      # Validate move
      validator = MoveValidator.new(fen: current_fen)
      unless validator.valid_move?(move_notation)
        return {
          success: false,
          move: nil,
          error: "Invalid move: #{move_notation}"
        }
      end

      # Apply move to get new FEN
      new_fen = validator.apply_move(move_notation)

      # Create move record
      move = match.moves.create!(
        player: :agent,
        move_number: match.moves.count + 1,
        move_notation: move_notation,
        board_state_before: current_fen,
        board_state_after: new_fen,
        response_time_ms: 0
      )

      {
        success: true,
        move: move,
        error: nil
      }
    rescue ActiveRecord::RecordNotFound
      {
        success: false,
        move: nil,
        error: "Match not found"
      }
    rescue StandardError => e
      Rails.logger.error("Error in SubmitMove: #{e.class} - #{e.message}")
      {
        success: false,
        move: nil,
        error: "An error occurred while submitting the move"
      }
    end
  end
end
```

**Step 5: Register mutation in MutationType**

Modify `app/graphql/types/mutation_type.rb`, add this field:

```ruby
field :submit_move, mutation: Mutations::SubmitMove
```

**Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/graphql/mutations/submit_move_spec.rb`
Expected: All tests PASS

**Step 7: Commit**

```bash
git add app/graphql/mutations/submit_move.rb \
        app/graphql/types/payloads/submit_move_payload.rb \
        app/graphql/types/mutation_type.rb \
        spec/requests/graphql/mutations/submit_move_spec.rb
git commit -m "feat: Add SubmitMove GraphQL mutation for human move submission"
```

---

## PR 2: Backend - Stockfish Response Job

### Task 2.1: Add StockfishResponseJob

**Files:**
- Create: `app/jobs/stockfish_response_job.rb`
- Create: `spec/jobs/stockfish_response_job_spec.rb`
- Modify: `app/graphql/mutations/submit_move.rb`
- Create: `app/channels/match_channel.rb`
- Create: `spec/channels/match_channel_spec.rb`

**Step 1: Write the failing test for StockfishResponseJob**

Create `spec/jobs/stockfish_response_job_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe StockfishResponseJob, type: :job do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, status: :in_progress, stockfish_level: 1) }
  let!(:first_move) do
    create(:move, :agent_move,
           match: match,
           move_number: 1,
           move_notation: "e4",
           board_state_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  end

  describe "#perform" do
    it "creates a stockfish move" do
      expect {
        described_class.new.perform(match.id)
      }.to change { match.moves.count }.by(1)

      stockfish_move = match.moves.last
      expect(stockfish_move.player).to eq("stockfish")
      expect(stockfish_move.move_number).to eq(2)
      expect(stockfish_move.move_notation).to be_present
    end

    it "broadcasts the move via ActionCable" do
      expect(MatchChannel).to receive(:broadcast_to).with(
        match,
        hash_including(type: "move_added")
      )

      described_class.new.perform(match.id)
    end

    context "when game ends in checkmate" do
      let!(:setup_moves) do
        # Scholar's mate setup - one move before checkmate
        match.moves.destroy_all
        create(:move, :agent_move, match: match, move_number: 1,
               move_notation: "e4",
               board_state_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
        create(:move, :stockfish_move, match: match, move_number: 2,
               move_notation: "e5",
               board_state_after: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2")
        create(:move, :agent_move, match: match, move_number: 3,
               move_notation: "Bc4",
               board_state_after: "rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2")
        create(:move, :stockfish_move, match: match, move_number: 4,
               move_notation: "Nc6",
               board_state_after: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR w KQkq - 2 3")
        create(:move, :agent_move, match: match, move_number: 5,
               move_notation: "Qh5",
               board_state_after: "r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 3 3")
        create(:move, :stockfish_move, match: match, move_number: 6,
               move_notation: "Nf6",
               board_state_after: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
        # Now agent plays Qxf7# for checkmate
        create(:move, :agent_move, match: match, move_number: 7,
               move_notation: "Qxf7",
               board_state_after: "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4")
      end

      it "marks match as completed and sets winner" do
        described_class.new.perform(match.id)

        match.reload
        expect(match.status).to eq("completed")
        expect(match.winner).to eq("agent")
      end
    end

    context "when game ends in stalemate" do
      # Simplified stalemate test - just verify the detection works
      it "marks match as draw" do
        # Mock the validator to return stalemate
        validator = instance_double(MoveValidator)
        allow(MoveValidator).to receive(:new).and_return(validator)
        allow(validator).to receive(:apply_move).and_return("some_fen")
        allow(validator).to receive(:game_over?).and_return(true)
        allow(validator).to receive(:result).and_return("stalemate")

        allow(StockfishService).to receive(:get_move).and_return("Kh1")

        described_class.new.perform(match.id)

        match.reload
        expect(match.status).to eq("completed")
        expect(match.winner).to eq("draw")
      end
    end

    context "when Stockfish times out" do
      it "retries up to 3 times" do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::TimeoutError.new("Timeout"))

        expect {
          described_class.new.perform(match.id)
        }.to have_enqueued_job(described_class).at_least(2).times
      end
    end

    context "when Stockfish crashes" do
      it "retries up to 2 times" do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::EngineError.new("Crash"))

        expect {
          described_class.new.perform(match.id)
        }.to have_enqueued_job(described_class).at_least(1).times
      end
    end

    context "when retries are exhausted" do
      before do
        allow(StockfishService).to receive(:get_move)
          .and_raise(StockfishService::TimeoutError.new("Timeout"))
      end

      it "marks match as errored" do
        # Disable retries for this test
        perform_enqueued_jobs do
          described_class.new.perform(match.id)
        rescue StockfishService::TimeoutError
          # Expected to raise after retries
        end

        match.reload
        expect(match.status).to eq("errored")
      end

      it "broadcasts error message" do
        expect(MatchChannel).to receive(:broadcast_to).with(
          match,
          hash_including(type: "error")
        )

        perform_enqueued_jobs do
          described_class.new.perform(match.id)
        rescue StockfishService::TimeoutError
          # Expected
        end
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/stockfish_response_job_spec.rb`
Expected: FAIL with "uninitialized constant StockfishResponseJob"

**Step 3: Create MatchChannel**

Create `app/channels/match_channel.rb`:

```ruby
class MatchChannel < ApplicationCable::Channel
  def subscribed
    match = Match.find(params[:match_id])
    stream_for match
  end

  def unsubscribed
    stop_all_streams
  end
end
```

**Step 4: Create MatchChannel spec**

Create `spec/channels/match_channel_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe MatchChannel, type: :channel do
  let(:match) { create(:match) }

  it "subscribes to a stream for the match" do
    subscribe(match_id: match.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(match)
  end
end
```

**Step 5: Create StockfishResponseJob**

Create `app/jobs/stockfish_response_job.rb`:

```ruby
class StockfishResponseJob < ApplicationJob
  queue_as :default

  retry_on StockfishService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on StockfishService::EngineError, wait: 5.seconds, attempts: 2

  discard_on ActiveJob::DeserializationError

  def perform(match_id)
    match = Match.find(match_id)
    current_fen = match.moves.last.board_state_after

    # Get Stockfish move
    stockfish_move = StockfishService.get_move(current_fen, match.stockfish_level)

    # Apply move and get new FEN
    validator = MoveValidator.new(fen: current_fen)
    new_fen = validator.apply_move(stockfish_move)

    # Save move
    move = match.moves.create!(
      player: :stockfish,
      move_number: match.moves.count + 1,
      move_notation: stockfish_move,
      board_state_before: current_fen,
      board_state_after: new_fen,
      response_time_ms: 0
    )

    # Check if game is over
    if validator.game_over?
      result = validator.result
      winner = determine_winner(result, move.player)
      match.update!(status: :completed, winner: winner)
    end

    # Broadcast move
    MatchChannel.broadcast_to(match, {
      type: "move_added",
      move: MoveSerializer.new(move).as_json
    })
  rescue StandardError => e
    # After retries exhausted, mark as errored
    match.update!(status: :errored)
    MatchChannel.broadcast_to(match, {
      type: "error",
      message: "Stockfish encountered an error"
    })
    raise
  end

  private

  def determine_winner(result, last_player)
    case result
    when "checkmate"
      # Winner is whoever made the last move
      last_player == "agent" ? :agent : :stockfish
    when "stalemate"
      :draw
    else
      nil
    end
  end
end
```

**Step 6: Add MoveSerializer**

Create `app/serializers/move_serializer.rb`:

```ruby
class MoveSerializer
  def initialize(move)
    @move = move
  end

  def as_json
    {
      id: @move.id,
      move_number: @move.move_number,
      player: @move.player,
      move_notation: @move.move_notation,
      board_state_after: @move.board_state_after,
      created_at: @move.created_at.iso8601
    }
  end
end
```

**Step 7: Update SubmitMove mutation to enqueue job**

Modify `app/graphql/mutations/submit_move.rb`, after creating the move:

```ruby
# Create move record
move = match.moves.create!(
  player: :agent,
  move_number: match.moves.count + 1,
  move_notation: move_notation,
  board_state_before: current_fen,
  board_state_after: new_fen,
  response_time_ms: 0
)

# Enqueue Stockfish response
StockfishResponseJob.perform_later(match.id)

{
  success: true,
  move: move,
  error: nil
}
```

**Step 8: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/stockfish_response_job_spec.rb spec/channels/match_channel_spec.rb`
Expected: All tests PASS

**Step 9: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests PASS

**Step 10: Commit**

```bash
git add app/jobs/stockfish_response_job.rb \
        app/channels/match_channel.rb \
        app/serializers/move_serializer.rb \
        app/graphql/mutations/submit_move.rb \
        spec/jobs/stockfish_response_job_spec.rb \
        spec/channels/match_channel_spec.rb
git commit -m "feat: Add StockfishResponseJob with retry logic and ActionCable broadcasting"
```

---

## PR 3: Frontend - Move Input Form

### Task 3.1: Add Move Input Form to Match Page

**Files:**
- Modify: `app/views/matches/show.html.erb`
- Create: `app/javascript/controllers/move_form_controller.js`
- Modify: `app/javascript/controllers/index.js`

**Step 1: Add move form to match view**

Modify `app/views/matches/show.html.erb`, add after the board component:

```erb
<% if @match.status_in_progress? %>
  <div class="bg-white rounded-lg shadow-md p-6 mt-4"
       data-controller="move-form"
       data-match-id="<%= @match.id %>">
    <h2 class="text-xl font-bold mb-4">Your Move</h2>

    <%= form_with url: "#", method: :post, data: { action: "submit->move-form#submit" } do |f| %>
      <div class="flex gap-2">
        <%= f.text_field :move_notation,
            placeholder: "e.g., e4, Nf3, O-O",
            class: "flex-1 px-3 py-2 border border-gray-300 rounded-md",
            data: { move_form_target: "input" } %>
        <%= f.submit "Submit Move",
            disabled: @match.moves.last&.player_agent?,
            class: "px-4 py-2 bg-blue-600 text-white rounded-md disabled:bg-gray-400 disabled:cursor-not-allowed",
            data: { move_form_target: "submit" } %>
      </div>
    <% end %>

    <div data-move-form-target="error" class="mt-2 text-red-600 text-sm"></div>
    <div data-move-form-target="status" class="mt-2 text-gray-600 text-sm"></div>

    <% if @match.moves.last&.player_agent? %>
      <p class="mt-2 text-sm text-gray-500">Waiting for Stockfish...</p>
    <% end %>
  </div>
<% elsif @match.status_completed? %>
  <div class="bg-white rounded-lg shadow-md p-6 mt-4">
    <h2 class="text-xl font-bold mb-2">Game Over</h2>
    <p class="text-lg">
      <% if @match.winner_draw? %>
        Draw by stalemate
      <% elsif @match.winner_agent? %>
        Human wins by checkmate!
      <% else %>
        Stockfish wins by checkmate
      <% end %>
    </p>
  </div>
<% end %>
```

**Step 2: Create move form Stimulus controller**

Create `app/javascript/controllers/move_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "error", "status"]

  async submit(event) {
    event.preventDefault()

    const notation = this.inputTarget.value.trim()
    if (!notation) {
      this.showError("Please enter a move")
      return
    }

    this.submitTarget.disabled = true
    this.clearError()
    this.showStatus("Submitting move...")

    try {
      const response = await this.submitMove(notation)

      if (response.success) {
        this.inputTarget.value = ""
        this.showStatus("Waiting for Stockfish...")
        // Button stays disabled until Stockfish move arrives via ActionCable
      } else {
        this.showError(response.error || "Failed to submit move")
        this.submitTarget.disabled = false
        this.clearStatus()
      }
    } catch (error) {
      console.error("Error submitting move:", error)
      this.showError("An error occurred while submitting the move")
      this.submitTarget.disabled = false
      this.clearStatus()
    }
  }

  async submitMove(notation) {
    const matchId = this.element.dataset.matchId

    const query = `
      mutation($matchId: ID!, $moveNotation: String!) {
        submitMove(matchId: $matchId, moveNotation: $moveNotation) {
          success
          move {
            id
            moveNotation
            player
          }
          error
        }
      }
    `

    const response = await fetch("/graphql", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({
        query,
        variables: {
          matchId,
          moveNotation: notation
        }
      })
    })

    const { data } = await response.json()
    return data.submitMove
  }

  showError(message) {
    this.errorTarget.textContent = message
  }

  clearError() {
    this.errorTarget.textContent = ""
  }

  showStatus(message) {
    this.statusTarget.textContent = message
  }

  clearStatus() {
    this.statusTarget.textContent = ""
  }

  // Called from match_subscription_controller when Stockfish move arrives
  enableSubmit() {
    this.submitTarget.disabled = false
    this.clearStatus()
  }
}
```

**Step 3: Register controller**

Modify `app/javascript/controllers/index.js` to ensure move-form controller is registered:

```javascript
import MoveFormController from "./move_form_controller"
application.register("move-form", MoveFormController)
```

**Step 4: Test manually**

Run: `rails server`
Navigate to a match page
Try submitting a valid move (e.g., "e4")
Expected: Form submits, button disables, status shows "Waiting for Stockfish..."

**Step 5: Commit**

```bash
git add app/views/matches/show.html.erb \
        app/javascript/controllers/move_form_controller.js \
        app/javascript/controllers/index.js
git commit -m "feat: Add move input form with GraphQL submission"
```

---

## PR 4: Frontend - ActionCable Integration

### Task 4.1: Update Match Subscription Controller

**Files:**
- Modify: `app/javascript/controllers/match_subscription_controller.js`

**Step 1: Update match subscription controller to handle moves**

Modify `app/javascript/controllers/match_subscription_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = { matchId: String }
  static targets = []

  connect() {
    console.log("Match subscription controller connected for match", this.matchIdValue)

    this.subscription = consumer.subscriptions.create(
      {
        channel: "MatchChannel",
        match_id: this.matchIdValue
      },
      {
        received: this.received.bind(this)
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  received(data) {
    console.log("Received data:", data)

    if (data.type === "move_added") {
      this.handleMoveAdded(data.move)
    } else if (data.type === "error") {
      this.handleError(data.message)
    }
  }

  handleMoveAdded(move) {
    // Update chess board
    const chessBoardElement = document.querySelector("[data-controller='chess-board']")
    if (chessBoardElement) {
      const chessBoardController = this.application.getControllerForElementAndIdentifier(
        chessBoardElement,
        "chess-board"
      )
      if (chessBoardController) {
        chessBoardController.positionValue = move.board_state_after
      }
    }

    // Re-enable submit button if it's a Stockfish move
    if (move.player === "stockfish") {
      const moveFormElement = document.querySelector("[data-controller='move-form']")
      if (moveFormElement) {
        const moveFormController = this.application.getControllerForElementAndIdentifier(
          moveFormElement,
          "move-form"
        )
        if (moveFormController) {
          moveFormController.enableSubmit()
        }
      }
    }

    // Check if game is over by looking for game over message on page
    // (This will be present if match status changed to completed)
    const gameOverElement = document.querySelector(".game-over-message")
    if (gameOverElement) {
      // Reload page to show final state
      window.location.reload()
    }
  }

  handleError(message) {
    alert(`Match error: ${message}`)
    // Reload page to show error state
    window.location.reload()
  }
}
```

**Step 2: Test manually**

Run: `rails server`
Create a match with Human Player agent
Submit a valid move (e.g., "e4")
Expected:
1. Board updates to show your move
2. After a few seconds, board updates again with Stockfish's response
3. Submit button re-enables

**Step 3: Commit**

```bash
git add app/javascript/controllers/match_subscription_controller.js
git commit -m "feat: Handle move broadcasts and board updates via ActionCable"
```

---

## PR 5: Seed Data

### Task 5.1: Add Human Player Agent

**Files:**
- Modify: `db/seeds.rb`

**Step 1: Add Human Player agent to seeds**

Modify `db/seeds.rb`, add after existing agent creation:

```ruby
# Human Player agent for testing
human_agent = Agent.find_or_create_by!(name: "Human Player") do |agent|
  agent.description = "Temporary human player for testing game flow before agent integration"
end
puts "Human Player agent: #{human_agent.name}"
```

**Step 2: Run seeds**

Run: `rails db:seed`
Expected: Output includes "Human Player agent: Human Player"

**Step 3: Verify in console**

Run: `rails console`

```ruby
Agent.find_by(name: "Human Player")
# => #<Agent id: X, name: "Human Player", ...>
```

**Step 4: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: Add Human Player agent for human vs stockfish testing"
```

---

## Testing the Complete Flow

### Manual Test Checklist

**Step 1: Run seeds**
```bash
rails db:seed
```

**Step 2: Start server**
```bash
rails server
```

**Step 3: Create a human match via GraphQL**

Open `http://localhost:3000/graphiql`

```graphql
mutation {
  createMatch(
    input: {
      agentId: "<HUMAN_PLAYER_AGENT_ID>",
      stockfishLevel: 1
    }
  ) {
    match {
      id
      status
    }
    errors
  }
}
```

**Step 4: Navigate to match**

Visit `http://localhost:3000/matches/<MATCH_ID>`

**Step 5: Play a game**

1. Submit "e4" → Board updates, Stockfish responds
2. Submit "d4" → Board updates, Stockfish responds
3. Continue playing until checkmate or stalemate
4. Verify game over message appears

**Expected Results:**
- ✅ Form only enabled on your turn
- ✅ Invalid moves show error
- ✅ Board updates after each move
- ✅ Stockfish responds automatically
- ✅ Game ends properly with winner/draw message
- ✅ No JavaScript errors in console

---

## Verification Steps

After completing all PRs:

1. **Run full test suite**: `bundle exec rspec`
   - Expected: All tests pass
   - Expected coverage: > 75%

2. **Run linter**: `bin/rubocop`
   - Expected: No offenses

3. **Check CI**: All checks pass (lint, test, scan)

4. **Manual testing**: Complete the manual test checklist above

5. **Code review**: Request review on all 5 PRs

---

## Future: Transition to Agents

When ready to replace human input with LLM agents:

**Remove:**
- Move input form from `matches/show.html.erb`
- `move_form_controller.js`
- Human Player agent from seeds
- Turn-based button logic

**Add:**
- Agent move generation service (calls LLM API)
- Job to trigger agent moves (replaces human form submission)
- Prompt construction (board state + valid moves + history)

**Keep (unchanged):**
- `SubmitMove` GraphQL mutation
- `StockfishResponseJob`
- `MatchChannel` broadcasting
- Board update logic
- Game over detection

The agent will call the same `submitMove` mutation that humans currently use.
