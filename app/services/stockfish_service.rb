require "open3"
require "timeout"

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

    # Register finalizer to ensure cleanup
    ObjectSpace.define_finalizer(self, self.class.finalize(@pid))
  end

  # Finalizer for cleanup when object is garbage collected
  def self.finalize(pid)
    proc {
      begin
        Process.kill("TERM", pid) if pid
        # Don't use Timeout in finalizer - it causes ThreadError in trap context
        Process.wait(pid, Process::WNOHANG) if pid
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already dead - that's okay
      end
    }
  end

  # Get Stockfish's move for a given position
  # Returns: { move: "e4", time_ms: 150 }
  def get_move(fen)
    # Validate FEN before sending to engine
    validate_fen!(fen)

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

      # Wait for process with timeout
      if @pid
        Timeout.timeout(2) { Process.wait(@pid) }
      end
    rescue Timeout::Error
      # Force kill if graceful shutdown times out
      Process.kill("TERM", @pid) if @pid
    rescue Errno::ESRCH, Errno::ECHILD
      # Process already dead - that's fine
    rescue => e
      # Log but don't raise - we're cleaning up
      Rails.logger.warn("Error closing Stockfish: #{e.message}")
    ensure
      @engine = nil
      @pid = nil
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
    game.board.generate_all_moves.each do |san_move|
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

  def validate_fen!(fen)
    # Validate FEN by trying to load it with chess gem
    Chess::Game.load_fen(fen)
  rescue ArgumentError => e
    # Chess gem raises ArgumentError for invalid FEN
    raise StockfishError, "Invalid FEN notation: #{fen} - #{e.message}"
  rescue => e
    # Catch any other errors from chess gem
    raise StockfishError, "Invalid FEN notation: #{fen} - #{e.message}"
  end
end
