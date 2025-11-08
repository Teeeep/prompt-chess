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
        move_number: match.moves.maximum(:move_number).to_i + 1,
        move_notation: move_notation,
        board_state_before: current_fen,
        board_state_after: new_fen,
        response_time_ms: 0
      )

      # Broadcast the human move
      MatchChannel.broadcast_to(match, {
        type: "move_added",
        move: MoveSerializer.new(move).as_json
      })

      # Enqueue Stockfish response
      StockfishResponseJob.perform_later(match.id)

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
