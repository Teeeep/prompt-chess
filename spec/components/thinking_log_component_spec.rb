require 'rails_helper'

RSpec.describe ThinkingLogComponent, type: :component do
  it "renders thinking log card" do
    move = create(:move, :agent_move, move_number: 1, move_notation: 'e4')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Latest Thinking')
  end

  it "shows move details" do
    move = create(:move, :agent_move, move_number: 1, move_notation: 'e4',
                  tokens_used: 150, response_time_ms: 750)
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Move 1: e4')
    expect(page).to have_content('150 tokens')
    expect(page).to have_content('750ms')
  end

  it "has collapsible prompt section" do
    move = create(:move, :agent_move, llm_prompt: 'Test prompt content')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Show Prompt')
    expect(page).to have_css('details')
  end

  it "has collapsible response section" do
    move = create(:move, :agent_move, llm_response: 'Test response content')
    render_inline(ThinkingLogComponent.new(move: move))

    expect(page).to have_content('Show Response')
    expect(page).to have_css('details')
  end

  it "shows empty message when no move" do
    render_inline(ThinkingLogComponent.new(move: nil))

    expect(page).to have_content('No agent moves yet')
  end
end
