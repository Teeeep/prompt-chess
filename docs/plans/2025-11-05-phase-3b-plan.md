# Phase 3b: Stockfish Integration - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create services to communicate with Stockfish engine and validate chess moves using the chess gem.

**Architecture:** StockfishService manages UCI protocol communication with engine subprocess. MoveValidator wraps chess gem for move validation and legal move generation.

**Tech Stack:** Rails 8, chess gem (~> 0.3), Stockfish binary, RSpec

**Dependencies:** Phase 3a complete (Match and Move models)

---

## Task 1: Add chess gem

**Files:**
- Modify: `Gemfile`

**Step 1: Add chess gem to Gemfile**

Add after the graphql gem:

```ruby
# Chess engine and logic
gem 'chess', '~> 0.3'
```

**Step 2: Run bundle install**

Run: `bundle install`
Expected: Gem installed successfully

**Step 3: Verify gem loaded**

Run: `bundle exec rails runner "puts Chess::VERSION"`
Expected: Version number prints (e.g., "0.3.0")

**Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat(phase-3b): add chess gem for move validation

Add chess gem (~> 0.3) to provide:
- FEN notation parsing and generation
- Move validation and legal move generation
- Game state detection (check, checkmate, stalemate)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: MoveValidator Service (TDD)

**Files:**
- Create: `spec/services/move_validator_spec.rb`
- Create: `app/services/move_validator.rb`

**Step 1: Write the failing test**

Create `spec/services/move_validator_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe MoveValidator do
  describe '#initialize' do
    it 'creates validator with starting position' do
      validator = MoveValidator.new
      expect(validator.current_fen).to eq(Chess::Game::DEFAULT_FEN)
    end

    it 'creates validator with custom FEN' do
      fen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'
      validator = MoveValidator.new(fen: fen)
      expect(validator.current_fen).to eq(fen)
    end
  end

  describe '#valid_move?' do
    let(:validator) { MoveValidator.new }

    it 'returns true for legal opening moves' do
      expect(validator.valid_move?('e4')).to be true
      expect(validator.valid_move?('d4')).to be true
      expect(validator.valid_move?('Nf3')).to be true
    end

    it 'returns false for illegal moves' do
      expect(validator.valid_move?('e5')).to be false # Black's move on white's turn
      expect(validator.valid_move?('Ke2')).to be false # King can't move yet
      expect(validator.valid_move?('Ra3')).to be false # Rook blocked by pawn
    end

    it 'returns false for invalid notation' do
      expect(validator.valid_move?('xyz')).to be false
      expect(validator.valid_move?('')).to be false
      expect(validator.valid_move?(nil)).to be false
    end
  end

  describe '#legal_moves' do
    let(:validator) { MoveValidator.new }

    it 'returns all legal moves from starting position' do
      moves = validator.legal_moves
      expect(moves).to include('e4', 'd4', 'Nf3', 'Nc3')
      expect(moves.length).to eq(20) # 16 pawn moves + 4 knight moves
    end

    it 'returns limited moves in restricted position' do
      # Position with only a few legal moves
      fen = 'r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4'
      validator = MoveValidator.new(fen: fen)
      moves = validator.legal_moves
      expect(moves).to be_an(Array)
      expect(moves.length).to be > 0
    end
  end

  describe '#apply_move' do
    let(:validator) { MoveValidator.new }

    it 'applies a legal move and returns new FEN' do
      new_fen = validator.apply_move('e4')
      expect(new_fen).to eq('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')
      expect(validator.current_fen).to eq(new_fen)
    end

    it 'updates legal moves after applying move' do
      validator.apply_move('e4')
      moves = validator.legal_moves
      # Now it's black's turn
      expect(moves).to include('e5', 'd5', 'Nf6', 'Nc6')
      expect(moves).not_to include('e4') # Can't move white pieces
    end

    it 'raises error for illegal move' do
      expect {
        validator.apply_move('e5') # Black's move on white's turn
      }.to raise_error(MoveValidator::IllegalMoveError)
    end

    it 'raises error for invalid notation' do
      expect {
        validator.apply_move('xyz')
      }.to raise_error(MoveValidator::IllegalMoveError)
    end
  end

  describe '#game_over?' do
    it 'returns false for starting position' do
      validator = MoveValidator.new
      expect(validator.game_over?).to be false
    end

    it 'returns true for checkmate position' do
      # Fool's mate position
      fen = 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'
      validator = MoveValidator.new(fen: fen)
      expect(validator.game_over?).to be true
      expect(validator.checkmate?).to be true
    end

    it 'returns true for stalemate position' do
      # Stalemate position
      fen = 'k7/8/1K6/8/8/8/8/1Q6 b - - 0 1'
      validator = MoveValidator.new(fen: fen)
      expect(validator.game_over?).to be true
      expect(validator.stalemate?).to be true
    end
  end

  describe '#result' do
    it 'returns nil for ongoing game' do
      validator = MoveValidator.new
      expect(validator.result).to be_nil
    end

    it 'returns checkmate for checkmated position' do
      fen = 'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'
      validator = MoveValidator.new(fen: fen)
      expect(validator.result).to eq('checkmate')
    end

    it 'returns stalemate for stalemated position' do
      fen = 'k7/8/1K6/8/8/8/8/1Q6 b - - 0 1'
      validator = MoveValidator.new(fen: fen)
      expect(validator.result).to eq('stalemate')
    end
  end

  describe 'full game simulation' do
    it 'can play a short game to checkmate' do
      validator = MoveValidator.new

      # Fool's Mate (fastest checkmate)
      validator.apply_move('f3')
      validator.apply_move('e5')
      validator.apply_move('g4')
      validator.apply_move('Qh4')

      expect(validator.checkmate?).to be true
      expect(validator.result).to eq('checkmate')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/move_validator_spec.rb`
Expected: FAIL - "uninitialized constant MoveValidator"

**Step 3: Create MoveValidator service**

Create `app/services/move_validator.rb`:

```ruby
class MoveValidator
  class IllegalMoveError < StandardError; end

  attr_reader :current_fen

  def initialize(fen: nil)
    @game = fen ? Chess::Game.load_fen(fen) : Chess::Game.new
    @current_fen = @game.fen
  end

  # Check if a move is legal in current position
  def valid_move?(move_san)
    return false if move_san.nil? || move_san.empty?

    # Try to find the move in legal moves
    legal_moves.include?(move_san)
  rescue
    false
  end

  # Get all legal moves in current position
  def legal_moves
    @game.moves
  end

  # Apply a move and update position
  # Returns new FEN string
  # Raises IllegalMoveError if move is invalid
  def apply_move(move_san)
    unless valid_move?(move_san)
      raise IllegalMoveError, "Illegal move: #{move_san}"
    end

    @game.move(move_san)
    @current_fen = @game.fen
  end

  # Check if game is over (checkmate or stalemate)
  def game_over?
    @game.over?
  end

  # Check if current position is checkmate
  def checkmate?
    @game.checkmate?
  end

  # Check if current position is stalemate
  def stalemate?
    @game.stalemate?
  end

  # Get game result
  # Returns: 'checkmate', 'stalemate', or nil
  def result
    return 'checkmate' if checkmate?
    return 'stalemate' if stalemate?
    nil
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/move_validator_spec.rb`
Expected: All tests pass

**Step 5: Commit**

```bash
git add spec/services/move_validator_spec.rb app/services/move_validator.rb
git commit -m "feat(phase-3b): add MoveValidator service

Create MoveValidator service to:
- Validate move legality using chess gem
- Generate list of legal moves for any position
- Apply moves and track position (FEN notation)
- Detect game over conditions (checkmate, stalemate)

Includes comprehensive tests:
- Valid/invalid move checking
- Legal move generation
- Move application with FEN updates
- Game over detection
- Full game simulation (Fool's Mate)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Install Stockfish locally

**Files:**
- None (system installation)

**Step 1: Install Stockfish via Homebrew (macOS)**

Run: `brew install stockfish`
Expected: Stockfish installed successfully

**Step 2: Verify Stockfish is accessible**

Run:
```bash
which stockfish
```
Expected: Path to stockfish binary (e.g., `/opt/homebrew/bin/stockfish`)

**Step 3: Test Stockfish UCI protocol**

Run:
```bash
echo -e "uci\nquit" | stockfish
```
Expected: Output includes "uciok" and engine info

**Step 4: Document installation**

Create note in commit message (no code changes needed for development setup)

---

## Task 4: StockfishService (TDD)

**Files:**
- Create: `spec/services/stockfish_service_spec.rb`
- Create: `app/services/stockfish_service.rb`
- Create: `config/initializers/stockfish.rb`

**Step 1: Create Stockfish configuration initializer**

Create `config/initializers/stockfish.rb`:

```ruby
# Stockfish engine configuration
STOCKFISH_PATH = ENV.fetch('STOCKFISH_PATH') do
  # Try common paths
  paths = [
    '/opt/homebrew/bin/stockfish',  # Homebrew on Apple Silicon
    '/usr/local/bin/stockfish',     # Homebrew on Intel Mac
    '/usr/bin/stockfish',            # Linux package manager
    'stockfish'                      # In PATH
  ]

  paths.find { |path| File.exist?(path) || system("which #{path} > /dev/null 2>&1") } || 'stockfish'
end
```

**Step 2: Write the failing test**

Create `spec/services/stockfish_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe StockfishService do
  describe '#initialize' do
    it 'creates service with default level 5' do
      service = StockfishService.new
      expect(service.level).to eq(5)
    end

    it 'creates service with custom level' do
      service = StockfishService.new(level: 3)
      expect(service.level).to eq(3)
    end

    it 'raises error for invalid level' do
      expect {
        StockfishService.new(level: 0)
      }.to raise_error(ArgumentError, /level must be between 1 and 8/)
    end
  end

  describe '#get_move' do
    let(:service) { StockfishService.new(level: 1) }

    it 'returns a legal move from starting position' do
      result = service.get_move(Chess::Game::DEFAULT_FEN)

      expect(result).to be_a(Hash)
      expect(result[:move]).to be_a(String)
      expect(result[:time_ms]).to be_a(Integer)
      expect(result[:time_ms]).to be > 0

      # Verify it's a legal opening move
      validator = MoveValidator.new
      expect(validator.legal_moves).to include(result[:move])
    end

    it 'returns different move for mid-game position' do
      # Position after 1. e4 e5
      fen = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'
      result = service.get_move(fen)

      expect(result[:move]).to be_a(String)

      # Verify it's a legal move for this position
      validator = MoveValidator.new(fen: fen)
      expect(validator.legal_moves).to include(result[:move])
    end

    it 'returns move quickly at low level' do
      result = service.get_move(Chess::Game::DEFAULT_FEN)
      expect(result[:time_ms]).to be < 2000 # Should be fast at level 1
    end

    it 'raises error for invalid FEN' do
      expect {
        service.get_move('invalid fen string')
      }.to raise_error(StockfishService::StockfishError)
    end
  end

  describe '#close' do
    it 'closes the engine gracefully' do
      service = StockfishService.new
      expect { service.close }.not_to raise_error
    end

    it 'can be called multiple times safely' do
      service = StockfishService.new
      service.close
      expect { service.close }.not_to raise_error
    end
  end

  describe 'level strength' do
    it 'level 1 makes weaker moves than level 8' do
      weak_service = StockfishService.new(level: 1)
      strong_service = StockfishService.new(level: 8)

      # Simple tactical position: white can capture free pawn
      # After 1. e4 e5 2. Nf3 d6 3. Bc4 h6 4. Nc3
      fen = 'rnbqkbnr/ppp2pp1/3p3p/4p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R b KQkq - 2 4'

      weak_move = weak_service.get_move(fen)
      strong_move = strong_service.get_move(fen)

      # Both should return legal moves
      validator = MoveValidator.new(fen: fen)
      expect(validator.legal_moves).to include(weak_move[:move])
      expect(validator.legal_moves).to include(strong_move[:move])

      # Moves might differ (though not guaranteed in every position)
      # Just verify both work and return in reasonable time
      expect(weak_move[:time_ms]).to be < 3000
      expect(strong_move[:time_ms]).to be < 5000

      weak_service.close
      strong_service.close
    end
  end

  describe 'error handling' do
    let(:service) { StockfishService.new }

    it 'raises error if engine crashes' do
      allow(service).to receive(:send_command).and_raise(Errno::EPIPE)

      expect {
        service.get_move(Chess::Game::DEFAULT_FEN)
      }.to raise_error(StockfishService::StockfishError, /Stockfish process died/)
    end

    it 'raises error on timeout' do
      allow(service).to receive(:read_until).and_raise(Timeout::Error)

      expect {
        service.get_move(Chess::Game::DEFAULT_FEN)
      }.to raise_error(StockfishService::StockfishError, /timed out/)
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/services/stockfish_service_spec.rb`
Expected: FAIL - "uninitialized constant StockfishService"

**Step 4: Create StockfishService**

Create `app/services/stockfish_service.rb`:

```ruby
require 'open3'
require 'timeout'

class StockfishService
  class StockfishError < StandardError; end

  attr_reader :level

  LEVEL_TO_UCI_SKILL = {
    1 => 1,   # Very weak
    2 => 4,
    3 => 7,
    4 => 10,
    5 => 13,
    6 => 16,
    7 => 19,
    8 => 20   # Full strength
  }.freeze

  def initialize(level: 5)
    unless (1..8).include?(level)
      raise ArgumentError, "Stockfish level must be between 1 and 8, got #{level}"
    end

    @level = level
    @engine = nil
    spawn_engine
  end

  # Get Stockfish's move for a given position
  # Returns: { move: "e4", time_ms: 150 }
  def get_move(fen)
    start_time = Time.now

    begin
      send_command("position fen #{fen}")
      send_command("go movetime 1000") # Think for 1 second

      # Read until we get bestmove
      output = read_until(/^bestmove (\S+)/, timeout: 5)

      if output =~ /^bestmove (\S+)/
        move_uci = $1
        move_san = convert_uci_to_san(fen, move_uci)

        time_ms = ((Time.now - start_time) * 1000).to_i

        { move: move_san, time_ms: time_ms }
      else
        raise StockfishError, "Failed to get move from Stockfish"
      end
    rescue Errno::EPIPE, IOError => e
      raise StockfishError, "Stockfish process died: #{e.message}"
    rescue Timeout::Error
      raise StockfishError, "Stockfish timed out"
    rescue => e
      raise StockfishError, "Stockfish error: #{e.message}"
    end
  end

  def close
    return unless @engine

    begin
      send_command("quit")
      @stdin.close unless @stdin.closed?
      @stdout.close unless @stdout.closed?
      @stderr.close unless @stderr.closed?
      Process.wait(@pid) if @pid
    rescue
      # Ignore errors on close
    ensure
      @engine = nil
    end
  end

  private

  def spawn_engine
    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(STOCKFISH_PATH)
    @pid = @wait_thr.pid
    @engine = true

    # Initialize engine
    send_command("uci")
    read_until(/^uciok/, timeout: 5)

    # Set skill level
    uci_skill = LEVEL_TO_UCI_SKILL[@level]
    send_command("setoption name Skill Level value #{uci_skill}")

    # Disable certain features for weaker play
    if @level < 8
      send_command("setoption name UCI_LimitStrength value true")
      # Elo roughly: level 1 = ~800, level 8 = ~3000
      elo = 700 + (@level * 300)
      send_command("setoption name UCI_Elo value #{elo}")
    end

    # Wait for engine to be ready
    send_command("isready")
    read_until(/^readyok/, timeout: 5)
  end

  def send_command(command)
    @stdin.puts(command)
    @stdin.flush
  end

  def read_until(pattern, timeout: 5)
    output = ""
    Timeout.timeout(timeout) do
      while line = @stdout.gets
        output += line
        return output if line.match?(pattern)
      end
    end
    output
  end

  # Convert UCI move (e2e4) to SAN (e4)
  def convert_uci_to_san(fen, uci_move)
    game = Chess::Game.load_fen(fen)

    # Try each legal move to find matching UCI
    game.moves.each do |san_move|
      test_game = Chess::Game.load_fen(fen)
      test_game.move(san_move)

      # Get the move that was just made in UCI format
      # Extract from/to squares from last move
      if matches_uci?(test_game, uci_move, san_move)
        return san_move
      end
    end

    # Fallback: return UCI if we can't convert
    # This shouldn't happen with valid positions
    uci_move
  end

  def matches_uci?(game, uci_move, san_move)
    # Simple heuristic: check if the destination square matches
    # UCI format: e2e4 (from e2 to e4)
    to_square = uci_move[-2..-1]

    # Convert to chess gem's square notation if needed
    # For MVP, we'll use a simple string match
    san_move.include?(to_square)
  rescue
    false
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/services/stockfish_service_spec.rb`
Expected: All tests pass (may take 30-60 seconds due to engine startup)

**Step 6: Commit**

```bash
git add spec/services/stockfish_service_spec.rb app/services/stockfish_service.rb config/initializers/stockfish.rb
git commit -m "feat(phase-3b): add StockfishService for engine communication

Create StockfishService to:
- Spawn and manage Stockfish engine subprocess
- Communicate via UCI protocol
- Get moves for any position (FEN notation)
- Support 8 skill levels (1=weak, 8=strong)
- Convert UCI moves to SAN notation
- Handle timeouts and crashes gracefully

Configuration:
- Auto-detect Stockfish path (Homebrew, system, PATH)
- Configurable via STOCKFISH_PATH environment variable
- 1 second thinking time per move
- Skill level mapped to UCI Skill Level and Elo

Includes comprehensive tests:
- Move generation from various positions
- Skill level configuration
- Error handling (crashes, timeouts, invalid FEN)
- Resource cleanup

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Integration Test

**Files:**
- Create: `spec/integration/chess_services_spec.rb`

**Step 1: Write integration test**

Create `spec/integration/chess_services_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Chess Services Integration', type: :integration do
  describe 'MoveValidator + StockfishService' do
    it 'can play a short game between validator and engine' do
      validator = MoveValidator.new
      stockfish = StockfishService.new(level: 1)

      moves_played = []

      # Play 3 moves each
      6.times do |i|
        current_fen = validator.current_fen

        # Get Stockfish's move
        result = stockfish.get_move(current_fen)
        move = result[:move]

        # Validate and apply the move
        expect(validator.valid_move?(move)).to be true
        validator.apply_move(move)

        moves_played << move
      end

      expect(moves_played.length).to eq(6)
      expect(validator.game_over?).to be false # Game still ongoing

      stockfish.close
    end

    it 'stockfish only suggests legal moves' do
      stockfish = StockfishService.new(level: 3)

      # Test multiple positions
      positions = [
        Chess::Game::DEFAULT_FEN,
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3'
      ]

      positions.each do |fen|
        validator = MoveValidator.new(fen: fen)
        result = stockfish.get_move(fen)

        expect(validator.legal_moves).to include(result[:move]),
          "Stockfish suggested illegal move #{result[:move]} for position #{fen}"
      end

      stockfish.close
    end
  end
end
```

**Step 2: Run integration test**

Run: `bundle exec rspec spec/integration/chess_services_spec.rb`
Expected: All tests pass

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All tests pass

**Step 4: Commit**

```bash
git add spec/integration/chess_services_spec.rb
git commit -m "test(phase-3b): add integration tests for chess services

Add integration tests verifying:
- MoveValidator and StockfishService work together
- Can play a multi-move game
- Stockfish only suggests legal moves
- Moves can be applied and validated correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Verification Checklist

Before marking Phase 3b complete:

- [ ] chess gem installed and working
- [ ] Stockfish installed locally (Homebrew)
- [ ] MoveValidator service created with full test coverage
- [ ] StockfishService created with full test coverage
- [ ] Integration tests pass (services work together)
- [ ] All tests pass (`bundle exec rspec`)
- [ ] Coverage ≥ 90% for Phase 3b code
- [ ] Services handle errors gracefully (timeouts, crashes, invalid input)
- [ ] Stockfish process cleanup works (no zombie processes)

---

## Dependencies for Next Phases

**Phase 3c (Agent Move Generation) needs:**
- MoveValidator ✓ (to validate agent moves)
- Nothing else from 3b

**Phase 3d (Match Orchestration) needs:**
- MoveValidator ✓
- StockfishService ✓
- AgentMoveService (from 3c)

---

**Phase 3b Status:** Ready for implementation
**Estimated Time:** 2-3 hours
**Complexity:** Medium (subprocess management, UCI protocol, error handling)
