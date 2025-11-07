class MatchRunner
  attr_reader :match

  def initialize(match:, session:)
    raise ArgumentError, "match is required" unless match
    raise ArgumentError, "session is required" unless session

    @match = match
    @session = session
    @validator = MoveValidator.new
    @stockfish = StockfishService.new(level: @match.stockfish_level)
  end

  def run!
    @match.update!(status: :in_progress, started_at: Time.current)

    begin
      current_player = :agent # Agent plays white, goes first

      until game_over?
        play_turn(player: current_player)

        # Alternate players
        current_player = current_player == :agent ? :stockfish : :agent
      end

      finalize_match
    rescue StandardError => e
      @match.update!(
        status: :errored,
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    ensure
      @stockfish&.close
    end
  end

  private

  def play_turn(player:)
    board_before = @validator.current_fen
    move_number = (@match.moves.count / 2) + 1

    if player == :agent
      play_agent_move(board_before, move_number)
    else
      play_stockfish_move(board_before, move_number)
    end
  end

  def play_agent_move(board_before, move_number)
    # Build move history for context
    move_history = @match.moves.order(:move_number).to_a

    # Generate move
    agent_service = AgentMoveService.new(
      agent: @match.agent,
      validator: @validator,
      move_history: move_history,
      session: @session
    )

    result = agent_service.generate_move

    # Apply move to validator
    board_after = @validator.apply_move(result[:move])

    # Create move record (counter_cache handles total_moves automatically)
    @match.moves.create!(
      move_number: move_number,
      player: :agent,
      move_notation: result[:move],
      board_state_before: board_before,
      board_state_after: board_after,
      llm_prompt: result[:prompt],
      llm_response: result[:response],
      tokens_used: result[:tokens],
      response_time_ms: result[:time_ms]
    )

    # Update match totals
    @match.increment!(:total_tokens_used, result[:tokens])

    # Broadcast update
    move = @match.moves.order(:move_number).last
    broadcast_update(move)
  end

  def play_stockfish_move(board_before, move_number)
    result = @stockfish.get_move(board_before)

    # Apply move to validator
    board_after = @validator.apply_move(result[:move])

    # Create move record (counter_cache handles total_moves automatically)
    @match.moves.create!(
      move_number: move_number,
      player: :stockfish,
      move_notation: result[:move],
      board_state_before: board_before,
      board_state_after: board_after,
      response_time_ms: result[:time_ms]
    )

    # Broadcast update
    move = @match.moves.order(:move_number).last
    broadcast_update(move)
  end

  def game_over?
    @validator.game_over?
  end

  def finalize_match
    result = @validator.result
    winner = determine_winner(result)

    # Calculate average move time
    agent_moves = @match.moves.where(player: :agent)
    avg_time = agent_moves.any? ? agent_moves.average(:response_time_ms).to_i : nil

    @match.update!(
      status: :completed,
      completed_at: Time.current,
      winner: winner,
      result_reason: result,
      final_board_state: @validator.current_fen,
      average_move_time_ms: avg_time
    )
  end

  def determine_winner(result)
    case result
    when 'checkmate'
      # Last move wins - check who moved last
      last_move = @match.moves.order(:move_number).last
      last_move.player == 'agent' ? :agent : :stockfish
    when 'stalemate'
      :draw
    else
      :draw
    end
  end

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
end
