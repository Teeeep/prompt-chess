require 'rails_helper'

RSpec.describe 'Match Viewing', type: :system do
  let(:agent) { create(:agent, name: 'Test Agent') }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }

  before do
    driven_by(:rack_test)
  end

  describe 'viewing a pending match' do
    it 'displays match information' do
      visit match_path(match)

      expect(page).to have_content("Match ##{match.id}")
      expect(page).to have_content('Test Agent')
      expect(page).to have_content('Stockfish Level 1')
      expect(page).to have_content('Pending')
    end

    it 'shows empty move list' do
      visit match_path(match)

      expect(page).to have_content('Moves')
      expect(page).to have_content('No moves yet')
    end

    it 'shows zero stats' do
      visit match_path(match)

      expect(page).to have_content('Moves:')
      expect(page).to have_content('0')
      expect(page).to have_content('Tokens:')
      expect(page).to have_content('0')
    end
  end

  describe 'viewing a match with moves' do
    let!(:move1) { create(:move, :agent_move, match: match, move_number: 1, move_notation: 'e4', tokens_used: 150) }
    let!(:move2) { create(:move, :stockfish_move, match: match, move_number: 2, move_notation: 'e5') }

    before do
      match.update!(total_tokens_used: 150)
    end

    it 'displays move history' do
      visit match_path(match)

      expect(page).to have_content('1.')
      expect(page).to have_content('e4')
      expect(page).to have_content('e5')
    end

    it 'displays updated stats' do
      visit match_path(match)

      expect(page).to have_content('Moves:')
      expect(page).to have_content('2')
      expect(page).to have_content('Tokens:')
      expect(page).to have_content('150')
    end

    it 'shows thinking log for agent move' do
      visit match_path(match)

      expect(page).to have_content('Latest Thinking')
      expect(page).to have_content('Move 1: e4')
      expect(page).to have_content('150 tokens')
    end
  end

  describe 'viewing a completed match' do
    before do
      match.update!(
        status: :completed,
        winner: :agent,
        result_reason: 'checkmate'
      )
    end

    it 'displays result' do
      visit match_path(match)

      expect(page).to have_content('Completed')
      expect(page).to have_content('Agent')
      expect(page).to have_content('Checkmate')
    end
  end
end
