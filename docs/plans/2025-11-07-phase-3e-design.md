# Phase 3e: Real-time UI - Design Document

**Date**: 2025-11-07
**Status**: Design Complete, Ready for Implementation
**Dependencies**: Phase 3a-3d complete

---

## Overview

### Goal
Create a real-time match viewing experience where users can watch chess games unfold live with full visibility into agent decision-making.

### User Experience
1. User navigates to `/matches/:id`
2. Sees live chessboard with pieces
3. Watches moves appear in real-time as the match executes
4. Views agent's thinking process (prompts, responses)
5. Monitors live statistics (tokens, cost, timing)
6. Sees final result when match completes

### Technical Approach
- **ViewComponents** for modular, testable UI components
- **GraphQL Subscriptions** via Action Cable for real-time updates
- **chessboard.js** for visual chess board display
- **Stimulus controllers** for interactive behavior
- **Tailwind CSS** for styling

---

## Architecture

### Real-time Data Flow

```
MatchRunner (background job)
    ↓
  [Move created]
    ↓
  broadcast_update()
    ↓
GraphQL Subscriptions
    ↓
Action Cable
    ↓
WebSocket → Browser
    ↓
Stimulus Controller
    ↓
Update UI Components
```

### Component Structure

```
MatchesController#show
  └── matches/show.html.erb
      ├── MatchBoardComponent (chessboard.js)
      ├── MatchStatsComponent (live stats)
      ├── MoveListComponent (move history)
      └── ThinkingLogComponent (agent prompts/responses)
```

---

## GraphQL Subscription Design

### Subscription Type

**Event**: `matchUpdated`
**Trigger**: After each move is played
**Payload**: Updated match + latest move

```graphql
subscription MatchUpdated($matchId: ID!) {
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
      boardStateAfter
    }
  }
}
```

### Broadcasting Points

MatchRunner broadcasts after:
1. Each agent move
2. Each Stockfish move
3. Match completion/error

---

## UI Components

### 1. MatchBoardComponent

**Purpose**: Display live chess board

**Technology**: chessboard.js (https://chessboardjs.com/)

**Features**:
- Visual 8x8 board with pieces
- Updates position when new moves arrive
- Highlights last move
- Shows whose turn it is

**Implementation**:
- Load chessboard.js via CDN
- Initialize with current FEN
- Update via Stimulus controller when subscription fires

### 2. MatchStatsComponent

**Purpose**: Live match statistics

**Displays**:
- Total moves
- Total tokens used
- Total cost (in dollars)
- Average move time
- Opening name (if detected)
- Match status badge
- Winner/result (when complete)

**Updates**: Real-time via subscription

### 3. MoveListComponent

**Purpose**: Scrollable move history

**Format**: Standard chess notation
```
1. e4   e5
2. Nf3  Nc6
3. Bb5  a6
```

**Features**:
- Auto-scrolls to latest move
- Highlights current move
- Shows full game history

### 4. ThinkingLogComponent

**Purpose**: Show agent's decision-making process

**Displays**:
- Latest agent move
- Full LLM prompt (collapsible)
- Full LLM response (collapsible)
- Token count
- Response time
- Move number and notation

**Updates**: When new agent move arrives

---

## Page Layout

```
┌─────────────────────────────────────────────────────────┐
│ Match #123                                              │
│ AgentName vs Stockfish Level 5                          │
│ [Status Badge: In Progress]                             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────┐  ┌──────────────────────────┐
│                         │  │ Match Stats              │
│    Chess Board          │  │ Moves: 12                │
│    (chessboard.js)      │  │ Tokens: 3,450            │
│                         │  │ Cost: $0.05              │
│    [Visual 8x8 board    │  │ Avg time: 850ms          │
│     with pieces]        │  │ Opening: Ruy Lopez       │
│                         │  └──────────────────────────┘
│                         │
│                         │  ┌──────────────────────────┐
│                         │  │ Moves                    │
└─────────────────────────┘  │ 1. e4   e5               │
                             │ 2. Nf3  Nc6              │
                             │ 3. Bb5  a6               │
                             │ 4. Ba4  Nf6              │
                             │ 5. O-O  Be7              │
                             │ 6. Re1  b5 ← (scrolling) │
                             └──────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Latest Thinking                                         │
│                                                         │
│ Move 6: Re1 • 750ms • 150 tokens                        │
│                                                         │
│ ▶ Show Prompt                                           │
│ ▶ Show Response                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Stimulus Controller Design

### MatchSubscriptionController

**Purpose**: Handle WebSocket subscription and UI updates

**Lifecycle**:
1. `connect()` - Establish GraphQL subscription via Action Cable
2. `received(data)` - Handle incoming updates
3. `disconnect()` - Clean up subscription

**Update Strategy (MVP)**:
- Simple approach: Reload page when update received
- Future enhancement: Update specific components via Turbo Streams

**Why reload for MVP?**
- Simplest implementation
- Works reliably
- Good enough for watching matches
- Can optimize later with targeted updates

---

## Implementation Tasks

### Task 1: GraphQL Subscription Setup
- Configure Action Cable in GraphQL schema
- Create `SubscriptionType` with `matchUpdated` field
- Create `MatchUpdatePayloadType`
- Create `GraphqlChannel` for Action Cable communication
- Test subscription establishes successfully

### Task 2: Broadcasting from MatchRunner
- Add `broadcast_update` method to MatchRunner
- Call after each agent move
- Call after each Stockfish move
- Call on match completion
- Write tests for broadcast behavior

### Task 3: Match Page View and Route
- Add `resources :matches, only: [:show]` route
- Create `MatchesController#show`
- Create basic `matches/show.html.erb` layout
- Add Stimulus data attributes for subscription

### Task 4: ViewComponents
- Install `view_component` gem
- Create `MatchBoardComponent` (chessboard.js integration)
- Create `MatchStatsComponent` (live stats)
- Create `MoveListComponent` (move history)
- Create `ThinkingLogComponent` (agent thinking)
- Style with Tailwind CSS

### Task 5: Stimulus Controller
- Create `match_subscription_controller.js`
- Implement GraphQL subscription via Action Cable
- Handle incoming match updates
- Reload page on update (MVP approach)

### Task 6: Chessboard.js Integration
- Add chessboard.js via CDN or npm
- Initialize board with current position
- Update position when new moves arrive
- Highlight last move

### Task 7: System Tests
- Test viewing pending match
- Test viewing match with moves
- Test move history display
- Test stats display
- Test thinking log
- Test completed match display

---

## Testing Strategy

### System Tests (Capybara + Selenium)

**Test scenarios**:
- Pending match displays correctly
- Match with moves shows board and history
- Stats update correctly
- Thinking log shows agent data
- Completed match shows result
- Expandable prompt/response sections work

### Component Tests (RSpec)

**Test each ViewComponent**:
- MatchBoardComponent renders with FEN
- MatchStatsComponent shows correct data
- MoveListComponent formats moves correctly
- ThinkingLogComponent handles nil moves

### Integration Test

**End-to-end flow**:
1. Create match via GraphQL
2. Visit match page
3. Verify initial state
4. Execute job
5. Verify updates arrive
6. Verify final state

---

## Dependencies

### Ruby Gems

```ruby
# Add to Gemfile
gem 'view_component', '~> 3.0'

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
```

### JavaScript Libraries

**chessboard.js**:
- Option 1: CDN (simplest for MVP)
- Option 2: npm install (if using asset pipeline)
- Dependency: jQuery (chessboard.js requires it)

**Already have**:
- Stimulus (Rails 8)
- Turbo (Rails 8)
- Action Cable (Rails 8)

---

## Security Considerations

### WebSocket Authentication
- Action Cable uses session cookies
- No additional auth needed for MVP
- Match visibility controlled by session

### Data Exposure
- All match data visible to anyone with URL (MVP)
- Future: Add user ownership checks
- LLM responses visible (by design for transparency)

---

## Performance Considerations

### Action Cable Scaling
- Handles ~1000 concurrent connections on single dyno
- MVP: <10 concurrent matches expected
- Good enough for initial launch

### Chessboard.js
- Lightweight library (~30kb)
- No performance concerns for single board
- Renders quickly even on mobile

### Subscription Efficiency
- One subscription per viewer per match
- Broadcasts only send changed data
- Minimal overhead

---

## Future Enhancements (Out of Scope)

- Targeted DOM updates instead of full page reload
- Board animation for moves
- Click-through move history
- Engine evaluation bar
- Multiple board themes
- Mobile-optimized layout
- PGN export button
- Share match URL

---

## Success Criteria

**Functional**:
- [ ] User can view match at `/matches/:id`
- [ ] Chess board displays current position
- [ ] Move list shows game history
- [ ] Stats update in real-time
- [ ] Thinking log shows agent prompts/responses
- [ ] Page updates when new moves played
- [ ] Completed matches show result

**Technical**:
- [ ] All tests pass
- [ ] ViewComponents render correctly
- [ ] GraphQL subscriptions work via Action Cable
- [ ] chessboard.js integrates successfully
- [ ] No console errors
- [ ] Coverage ≥ 90% for Phase 3e code

---

## Design Status

**Status**: ✅ Design Complete
**Next Step**: Create implementation plan
**Ready for**: Phase 3e implementation

---

**Design completed**: 2025-11-07
**Key decision**: Using chessboard.js instead of ASCII for better UX
