require 'rails_helper'

RSpec.describe MoveListComponent, type: :component do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent) }

  it "renders moves list card" do
    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('Moves')
  end

  it "shows empty message when no moves" do
    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('No moves yet')
  end

  it "displays moves in pairs (white, black)" do
    create(:move, :agent_move, match: match, move_number: 1, move_notation: 'e4')
    create(:move, :stockfish_move, match: match, move_number: 2, move_notation: 'e5')
    create(:move, :agent_move, match: match, move_number: 3, move_notation: 'Nf3')

    render_inline(MoveListComponent.new(match: match))

    expect(page).to have_content('1.')
    expect(page).to have_content('e4')
    expect(page).to have_content('e5')
    expect(page).to have_content('2.')
    expect(page).to have_content('Nf3')
  end
end
