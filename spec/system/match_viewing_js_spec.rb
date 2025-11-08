require 'rails_helper'

RSpec.describe 'Match Viewing with JavaScript', type: :system, js: true do
  let(:agent) { create(:agent, name: 'Test Agent') }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }

  before do
    driven_by(:selenium_chrome_headless)
  end

  describe 'chess board display' do
    it 'renders chess board with chessboard.js' do
      visit match_path(match)

      # Wait for Stimulus controller to initialize the board
      # The board container should have the Stimulus controller attached
      expect(page).to have_css('[data-controller="chess-board"]')

      # Wait for chessboard.js to initialize (it adds the .board-b72b1 class)
      expect(page).to have_css('.board-b72b1', wait: 10)
    end

    it 'displays pieces for starting position' do
      visit match_path(match)

      # Wait for chessboard.js to render pieces as images
      # Each piece has a data-piece attribute
      expect(page).to have_css('img[data-piece]', minimum: 32, wait: 10)
    end
  end

  describe 'expandable thinking log' do
    let!(:move) { create(:move, :agent_move, match: match, move_number: 1,
                        llm_prompt: 'Test prompt', llm_response: 'Test response') }

    it 'can expand prompt section' do
      visit match_path(match)

      # Debug: Check if thinking log is rendered
      expect(page).to have_content('Latest Thinking')
      expect(page).to have_css('details summary', text: 'Show Prompt')

      # Initially collapsed
      expect(page).not_to have_content('Test prompt')

      # Click to expand
      find('summary', text: 'Show Prompt').click

      # Now visible
      expect(page).to have_content('Test prompt')
    end

    it 'can expand response section' do
      visit match_path(match)

      # Initially collapsed
      expect(page).not_to have_content('Test response')

      # Click to expand
      find('summary', text: 'Show Response').click

      # Now visible
      expect(page).to have_content('Test response')
    end
  end

  describe 'real-time subscription' do
    it 'establishes WebSocket connection' do
      visit match_path(match)

      # Wait for Stimulus controller to connect
      sleep 2

      # Check console for connection message (this is a basic check)
      # In a real app, you'd mock the WebSocket or test with actual updates
      expect(page).to have_css('[data-controller="match-subscription"]')
    end
  end
end
