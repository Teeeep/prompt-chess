# Clear existing data
puts "Clearing existing data..."
Move.destroy_all
Match.destroy_all
Agent.destroy_all

# Create some agents
puts "Creating agents..."

agent1 = Agent.create!(
  name: "Chess Master Alpha",
  role: "aggressive_player",
  prompt_text: "You are an aggressive chess player who loves tactical combinations and sacrifices.",
  configuration: {
    provider: "anthropic",
    model: "claude-3-5-haiku-20241022"
  }
)

agent2 = Agent.create!(
  name: "Positional Pro",
  role: "positional_player",
  prompt_text: "You are a positional chess player who focuses on long-term strategy and piece placement.",
  configuration: {
    provider: "anthropic",
    model: "claude-3-5-sonnet-20241022"
  }
)

agent3 = Agent.create!(
  name: "Defensive Dan",
  role: "defensive_player",
  prompt_text: "You are a defensive chess player who prioritizes king safety and solid pawn structures.",
  configuration: {
    provider: "openai",
    model: "gpt-4o-mini"
  }
)

# Create a completed match with moves
puts "Creating completed match with moves..."
match1 = Match.create!(
  agent: agent1,
  stockfish_level: 1,
  status: :completed,
  winner: :agent,
  result_reason: "Stockfish resigned",
  total_tokens_used: 1250,
  total_cost_cents: 15,
  average_move_time_ms: 850
)

# Add some moves to the completed match
Move.create!(
  match: match1,
  move_number: 1,
  chess_move_number: 1,
  player: :agent,
  move_notation: "e4",
  board_state_before: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  board_state_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  llm_prompt: "You are Chess Master Alpha playing white. Choose your opening move.",
  llm_response: "I'll play the king's pawn opening, the most popular and aggressive first move. MOVE: e4",
  tokens_used: 125,
  response_time_ms: 650
)

Move.create!(
  match: match1,
  move_number: 2,
  chess_move_number: 1,
  player: :stockfish,
  move_notation: "e5",
  board_state_before: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  board_state_after: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  response_time_ms: 50
)

Move.create!(
  match: match1,
  move_number: 3,
  chess_move_number: 2,
  player: :agent,
  move_notation: "Nf3",
  board_state_before: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  board_state_after: "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
  llm_prompt: "Current position after 1.e4 e5. Develop your pieces.",
  llm_response: "I'll develop my knight to f3, attacking the e5 pawn and preparing to castle. MOVE: Nf3",
  tokens_used: 130,
  response_time_ms: 700
)

Move.create!(
  match: match1,
  move_number: 4,
  chess_move_number: 2,
  player: :stockfish,
  move_notation: "Nc6",
  board_state_before: "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2",
  board_state_after: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
  response_time_ms: 45
)

# Create an in-progress match
puts "Creating in-progress match..."
match2 = Match.create!(
  agent: agent2,
  stockfish_level: 3,
  status: :in_progress,
  total_tokens_used: 450,
  total_cost_cents: 5,
  average_move_time_ms: 920
)

Move.create!(
  match: match2,
  move_number: 1,
  chess_move_number: 1,
  player: :agent,
  move_notation: "d4",
  board_state_before: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  board_state_after: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
  llm_prompt: "You are Positional Pro playing white. Choose your opening move.",
  llm_response: "I'll play d4, the queen's pawn opening, aiming for solid central control. MOVE: d4",
  tokens_used: 135,
  response_time_ms: 800
)

Move.create!(
  match: match2,
  move_number: 2,
  chess_move_number: 1,
  player: :stockfish,
  move_notation: "d5",
  board_state_before: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1",
  board_state_after: "rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq d6 0 2",
  response_time_ms: 55
)

# Create a pending match
puts "Creating pending match..."
Match.create!(
  agent: agent3,
  stockfish_level: 5,
  status: :pending
)

puts "Seed data created successfully!"
puts "- 3 agents created"
puts "- 1 completed match with 4 moves"
puts "- 1 in-progress match with 2 moves"
puts "- 1 pending match"
