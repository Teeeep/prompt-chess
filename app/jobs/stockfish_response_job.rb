class StockfishResponseJob < ApplicationJob
  queue_as :default

  retry_on StockfishService::TimeoutError, wait: 5.seconds, attempts: 3 do |job, error|
    handle_retries_exhausted(job.arguments.first, error)
  end
  retry_on StockfishService::EngineError, wait: 5.seconds, attempts: 2 do |job, error|
    handle_retries_exhausted(job.arguments.first, error)
  end

  discard_on ActiveJob::DeserializationError

  def perform(match_id)
    match = Match.find(match_id)
    current_fen = match.moves.last&.board_state_after || MoveValidator::STARTING_FEN

    # Get Stockfish move
    stockfish_move = StockfishService.get_move(current_fen, match.stockfish_level)

    # Apply move and get new FEN
    validator = MoveValidator.new(fen: current_fen)
    new_fen = validator.apply_move(stockfish_move)

    # Save move
    move = match.moves.create!(
      player: :stockfish,
      move_number: match.moves.maximum(:move_number).to_i + 1,
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
  end

  private

  def self.handle_retries_exhausted(match_id, error)
    match = Match.find(match_id)
    match.update!(status: :errored)
    MatchChannel.broadcast_to(match, {
      type: "error",
      message: "Stockfish encountered an error"
    })
  end

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
