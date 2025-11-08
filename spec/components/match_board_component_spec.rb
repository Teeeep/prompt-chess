require 'rails_helper'

RSpec.describe MatchBoardComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent) }

  it "renders board container" do
    render_inline(MatchBoardComponent.new(match: match))

    expect(page).to have_css('[data-controller="chess-board"]')
    expect(page).to have_css('#board')
  end

  it "includes starting position FEN when no moves" do
    render_inline(MatchBoardComponent.new(match: match))

    expect(page).to have_css('[data-chess-board-position-value]')
    expect(page.find('[data-chess-board-position-value]')['data-chess-board-position-value'])
      .to eq(MatchBoardComponent::STARTING_FEN)
  end

  it "includes latest position FEN when moves exist" do
    move = create(:move, :agent_move, match: match, move_number: 1,
                  board_state_after: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1')

    render_inline(MatchBoardComponent.new(match: match))

    expect(page.find('[data-chess-board-position-value]')['data-chess-board-position-value'])
      .to eq(move.board_state_after)
  end
end
