FactoryBot.define do
  factory :match do
    agent
    stockfish_level { 5 }
    status { :pending }
    total_moves { 0 }
    total_tokens_used { 0 }
    total_cost_cents { 0 }

    trait :in_progress do
      status { :in_progress }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      winner { :agent }
      result_reason { 'checkmate' }
      total_moves { 42 }
      total_tokens_used { 3500 }
      total_cost_cents { 5 }
      average_move_time_ms { 850 }
      opening_name { 'Sicilian Defense' }
      final_board_state { 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3' }
    end

    trait :errored do
      status { :errored }
      error_message { 'Test error message' }
    end

    trait :agent_won do
      completed
      winner { :agent }
    end

    trait :stockfish_won do
      completed
      winner { :stockfish }
    end

    trait :draw do
      completed
      winner { :draw }
      result_reason { 'stalemate' }
    end
  end
end
