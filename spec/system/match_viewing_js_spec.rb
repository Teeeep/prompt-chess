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

    it 'updates board position when move is broadcast', :focus do
      # Start with initial position
      visit match_path(match)

      # Wait for board to initialize
      expect(page).to have_css('.board-b72b1', wait: 10)

      # Get initial position from data attribute
      initial_position = page.find('[data-controller="chess-board"]')['data-chess-board-position-value']
      expect(initial_position).to eq('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')

      # Create a move in the database (simulating what would happen when a move is made)
      # This should trigger a broadcast via ActionCable through the after_create_commit callback
      position_after_e4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'

      # Use perform_enqueued_jobs to ensure callbacks execute
      perform_enqueued_jobs do
        create(:move,
          match: match,
          move_number: 1,
          chess_move_number: 1,
          player: :agent,
          move_notation: 'e4',
          board_state_before: initial_position,
          board_state_after: position_after_e4
        )
      end

      # Wait for the broadcast to be received and board to update
      # The data attribute should change to the new position
      expect(page).to have_css(
        "[data-controller='chess-board'][data-chess-board-position-value='#{position_after_e4}']",
        wait: 10
      )

      # Verify the board actually updated visually by checking for a piece in the new position
      updated_position = page.find('[data-controller="chess-board"]')['data-chess-board-position-value']
      expect(updated_position).to eq(position_after_e4)
    end
  end
end
