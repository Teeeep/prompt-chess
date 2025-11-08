# Human vs Stockfish Design

**Date**: 2025-01-08
**Status**: Approved
**Purpose**: Temporary scaffolding to validate game flow before agent integration

## Overview

Enable humans to play chess against Stockfish through a text-based move submission interface. This validates the complete game flow (move submission → validation → opponent response → board update → game completion) before integrating LLM agents.

## Key Decisions

- **No schema changes**: Reuse existing Match/Move models
- **Dummy agent approach**: Create "Human Player" agent in seeds, use for all human matches
- **GraphQL API**: Submit moves via GraphQL mutation (same interface agents will use)
- **ActionCable for responses**: Leverage existing subscription infrastructure
- **Text input**: Simple move notation form (e.g., "e4"), not drag-and-drop
- **Temporary code**: Only frontend form and dummy agent are throwaway; GraphQL mutation and job are permanent

## Architecture

### Game Flow

1. Human creates match using existing `createMatch` GraphQL mutation with dummy "Human Player" agent
2. Match page shows chessboard + move input form
3. Human types move notation (e.g., "e4"), clicks submit (only enabled when it's their turn)
4. Backend validates with `MoveValidator`, saves move, enqueues `StockfishResponseJob`
5. Job gets Stockfish move, saves it, broadcasts via ActionCable
6. Stimulus controller receives broadcast, updates board position
7. After Stockfish move, check if game is over (checkmate/stalemate)
8. If game over: update match status to `:completed`, set winner, disable input

### Turn Logic

- Submit button enabled when: `match.moves.last&.player == 'stockfish'` (or no moves yet)
- Submit button disabled when: `match.moves.last&.player == 'agent'` (waiting for Stockfish)
- Uses simple last-move check, no additional fields needed

## Components

### Backend (Permanent)

**1. SubmitMove GraphQL Mutation**
```ruby
mutation {
  submitMove(matchId: ID!, moveNotation: String!) {
    success: Boolean!
    move: Move
    error: String
  }
}
```

**Responsibilities**:
- Load match and verify status is `:in_progress`
- Check it's the agent's turn (last move was Stockfish or no moves)
- Initialize `MoveValidator` with current board state
- Validate move with `MoveValidator.valid_move?`
- If valid: create Move record with `player: :agent`, enqueue `StockfishResponseJob`
- If invalid: return error message
- If wrong turn: return "Not your turn" error
- If match completed: return "Match already completed" error

**2. StockfishResponseJob**
```ruby
class StockfishResponseJob < ApplicationJob
  retry_on StockfishService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on StockfishService::EngineError, wait: 5.seconds, attempts: 2

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
      response_time_ms: 0 # Stockfish timing handled internally
    )

    # Check if game is over
    if validator.game_over?
      result = validator.result # 'checkmate' or 'stalemate'
      winner = determine_winner(result, move.player)
      match.update!(status: :completed, winner: winner)
    end

    # Broadcast move
    MatchChannel.broadcast_to(match, {
      type: 'move_added',
      move: MoveSerializer.new(move).as_json
    })
  rescue => e
    # After retries exhausted
    match.update!(status: :errored)
    MatchChannel.broadcast_to(match, {
      type: 'error',
      message: 'Stockfish encountered an error'
    })
  end
end
```

**Retry Strategy**:
- Timeout errors: 3 attempts with 5 second delays
- Engine crashes: 2 attempts with 5 second delays
- After all retries fail: mark match as `:errored`, broadcast error

### Frontend (Temporary - will be removed)

**1. Match Page Form** (app/views/matches/show.html.erb)
```erb
<% if @match.status_in_progress? %>
  <div class="move-input">
    <%= form_with url: "#", data: { controller: "move-form" } do |f| %>
      <%= f.text_field :move_notation, placeholder: "e.g., e4" %>
      <%= f.submit "Submit Move",
          disabled: @match.moves.last&.player == 'agent',
          data: { move_form_target: "submit" } %>
    <% end %>
    <div data-move-form-target="error" class="error"></div>
  </div>
<% end %>
```

**2. Move Form Stimulus Controller** (move_form_controller.js)
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "error"]

  async submit(event) {
    event.preventDefault()
    const notation = event.target.move_notation.value

    this.submitTarget.disabled = true
    this.errorTarget.textContent = ""

    const response = await this.submitMove(notation)

    if (!response.success) {
      this.errorTarget.textContent = response.error
      this.submitTarget.disabled = false
    }
    // On success, button stays disabled until Stockfish move arrives via ActionCable
  }

  async submitMove(notation) {
    const query = `
      mutation($matchId: ID!, $moveNotation: String!) {
        submitMove(matchId: $matchId, moveNotation: $moveNotation) {
          success
          move { id notation }
          error
        }
      }
    `

    const response = await fetch('/graphql', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query,
        variables: {
          matchId: this.element.dataset.matchId,
          moveNotation: notation
        }
      })
    })

    const { data } = await response.json()
    return data.submitMove
  }
}
```

**3. Match Subscription Controller Updates** (match_subscription_controller.js)
```javascript
// Add to existing controller
received(data) {
  if (data.type === 'move_added') {
    // Update board
    this.chessBoardController.positionValue = data.move.board_state_after

    // Re-enable submit button (it's our turn now)
    const submitButton = document.querySelector('[data-move-form-target="submit"]')
    if (submitButton) submitButton.disabled = false
  }

  if (data.type === 'error') {
    alert(data.message)
  }
}
```

### Seeds (Temporary)

```ruby
# db/seeds.rb
Agent.find_or_create_by!(name: "Human Player") do |agent|
  agent.description = "Temporary human player for testing game flow"
end
```

## Error Handling

### Invalid Move
- `MoveValidator.valid_move?` returns false
- Mutation returns: `{ success: false, error: "Invalid move: e9" }`
- Frontend shows error, keeps form enabled

### Wrong Turn
- Mutation checks: `match.moves.last&.player == 'agent'`
- Returns: `{ success: false, error: "Not your turn" }`
- Frontend button should prevent this, but server validates too

### Completed Match
- Mutation checks: `match.status_completed?`
- Returns: `{ success: false, error: "Match already completed" }`

### Stockfish Errors
- Job retries with exponential backoff
- After retries exhausted: `match.update!(status: :errored)`
- Broadcasts error to frontend
- Frontend shows: "Stockfish encountered an error. Match ended."

## Testing Strategy

### Unit Tests
- `SubmitMove` mutation: valid move, invalid move, wrong turn, completed match
- `StockfishResponseJob`: successful response, game over detection, retry logic

### Integration Tests
- Full flow: human move → validation → stockfish response → broadcast
- Game completion: checkmate/stalemate detection, winner assignment
- Error scenarios: stockfish failures with retries

### System Tests (Optional)
- Can add later for JavaScript/ActionCable interaction
- Not critical for temporary scaffolding

## Implementation Plan

### PR 1: Backend - Submit Move Mutation
- Add `SubmitMove` GraphQL mutation
- Add `SubmitMovePayload` type
- Validation logic (no Stockfish response yet)
- Unit tests for mutation
- ~100-150 lines changed

### PR 2: Backend - Stockfish Response Job
- Add `StockfishResponseJob`
- Integrate with mutation (enqueue job after move saved)
- Game over detection & match completion logic
- Retry logic for Stockfish errors
- Unit and integration tests
- ~150-200 lines changed

### PR 3: Frontend - Move Input Form
- Add form to match page
- Create `move_form_controller.js`
- Wire up GraphQL mutation call
- Button enable/disable based on turn
- Error display
- ~100 lines changed

### PR 4: Frontend - ActionCable Integration
- Update `match_subscription_controller.js`
- Handle `move_added` and `error` broadcasts
- Update board position on move received
- Re-enable submit button after Stockfish move
- Game over UI state
- ~75-100 lines changed

### PR 5: Seed Data
- Add "Human Player" dummy agent to seeds
- ~5 lines changed

## Future: Transition to Agents

When ready to switch to LLM agents:

**What stays** (permanent code):
- `SubmitMove` GraphQL mutation - agents call this
- `StockfishResponseJob` - handles opponent moves
- All game logic, validation, completion detection

**What goes** (temporary code):
- Move input form on match page
- `move_form_controller.js`
- "Human Player" dummy agent from seeds
- Turn-based button enable/disable logic

**What gets added**:
- Agent move generation service (calls LLM)
- Job to trigger agent moves (replaces human input)
- Agent prompt construction (board state + valid moves + history)

The architecture is designed so agents slot in cleanly where humans currently are - they just call the same `submitMove` mutation.
