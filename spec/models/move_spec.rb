require 'rails_helper'

RSpec.describe Move, type: :model do
  describe 'associations' do
    it 'belongs to match' do
      expect(Move.reflect_on_association(:match).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    let(:match) { create(:match) }

    it 'requires move_number' do
      move = Move.new(match: match, player: :agent, move_notation: 'e4',
                      board_state_before: 'fen1', board_state_after: 'fen2',
                      response_time_ms: 100)
      expect(move).not_to be_valid
      expect(move.errors[:move_number]).to be_present
    end

    it 'requires move_notation' do
      move = Move.new(match: match, move_number: 1, player: :agent,
                      board_state_before: 'fen1', board_state_after: 'fen2',
                      response_time_ms: 100)
      expect(move).not_to be_valid
      expect(move.errors[:move_notation]).to be_present
    end

    it 'requires board_state_after' do
      move = Move.new(match: match, move_number: 1, player: :agent,
                      move_notation: 'e4', board_state_before: 'fen1',
                      response_time_ms: 100)
      expect(move).not_to be_valid
      expect(move.errors[:board_state_after]).to be_present
    end

    it 'requires response_time_ms' do
      move = Move.new(match: match, move_number: 1, player: :agent,
                      move_notation: 'e4', board_state_before: 'fen1',
                      board_state_after: 'fen2')
      expect(move).not_to be_valid
      expect(move.errors[:response_time_ms]).to be_present
    end

    it 'requires move_number to be greater than 0' do
      move = Move.new(match: match, move_number: 0, player: :agent,
                      move_notation: 'e4', board_state_before: 'fen1',
                      board_state_after: 'fen2', response_time_ms: 100)
      expect(move).not_to be_valid
      expect(move.errors[:move_number]).to be_present
    end
  end

  describe 'enums' do
    it 'defines player enum' do
      expect(Move.players).to eq({
        'agent' => 0,
        'stockfish' => 1
      })
    end
  end

  describe 'ordering' do
    let(:match) { create(:match) }
    let!(:move3) { create(:move, match: match, move_number: 3) }
    let!(:move1) { create(:move, match: match, move_number: 1) }
    let!(:move2) { create(:move, match: match, move_number: 2) }

    it 'orders moves by move_number through association' do
      expect(match.moves.pluck(:move_number)).to eq([1, 2, 3])
    end
  end

  describe 'uniqueness' do
    let(:match) { create(:match) }
    let!(:existing_move) { create(:move, match: match, move_number: 1) }

    it 'prevents duplicate move_number for same match' do
      duplicate_move = Move.new(
        match: match,
        move_number: 1,
        player: :stockfish,
        move_notation: 'e5',
        board_state_before: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        board_state_after: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        response_time_ms: 100
      )

      expect(duplicate_move).not_to be_valid
      expect(duplicate_move.errors[:move_number]).to include('has already been taken')
    end
  end

  describe 'agent-specific fields' do
    let(:match) { create(:match) }

    it 'allows llm_prompt for agent moves' do
      move = create(:move, match: match, player: :agent, llm_prompt: 'Test prompt')
      expect(move.llm_prompt).to eq('Test prompt')
    end

    it 'allows llm_response for agent moves' do
      move = create(:move, match: match, player: :agent, llm_response: 'Test response')
      expect(move.llm_response).to eq('Test response')
    end

    it 'allows tokens_used for agent moves' do
      move = create(:move, match: match, player: :agent, tokens_used: 150)
      expect(move.tokens_used).to eq(150)
    end
  end
end
