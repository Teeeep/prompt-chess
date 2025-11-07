require 'rails_helper'

RSpec.describe MatchStatsComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, total_moves: 12, total_tokens_used: 3450, total_cost_cents: 5) }

  it "renders stats card" do
    # Create 12 moves so total_moves (which uses moves_count) returns 12
    12.times do |i|
      create(:move, match: match, move_number: i + 1, player: i.even? ? 'agent' : 'stockfish')
    end
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Stats')
    expect(page).to have_content('Moves:')
    expect(page).to have_content('12')
  end

  it "displays token count" do
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Tokens:')
    expect(page).to have_content('3,450')
  end

  it "displays cost in dollars" do
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Cost:')
    expect(page).to have_content('$0.05')
  end

  it "displays average move time when present" do
    match.update!(average_move_time_ms: 850)
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Avg time:')
    expect(page).to have_content('850ms')
  end

  it "displays winner when completed" do
    match.update!(status: :completed, winner: :agent, result_reason: 'checkmate')
    render_inline(MatchStatsComponent.new(match: match))

    expect(page).to have_content('Result:')
    expect(page).to have_content('Agent')
    expect(page).to have_content('Checkmate')
  end
end
