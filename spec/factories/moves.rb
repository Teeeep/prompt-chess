FactoryBot.define do
  factory :move do
    match
    sequence(:move_number) { |n| n }
    chess_move_number { (move_number + 1) / 2 }
    player { :agent }
    move_notation { 'e4' }
    board_state_before { 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' }
    board_state_after { 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1' }
    response_time_ms { 500 }

    trait :agent_move do
      player { :agent }
      llm_prompt { 'You are playing chess. Current position: rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1. Your move:' }
      llm_response { 'I will play e4. MOVE: e4' }
      tokens_used { 150 }
    end

    trait :stockfish_move do
      player { :stockfish }
      move_notation { 'e5' }
      board_state_before { 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1' }
      board_state_after { 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2' }
      response_time_ms { 50 }
      llm_prompt { nil }
      llm_response { nil }
      tokens_used { nil }
    end
  end
end
