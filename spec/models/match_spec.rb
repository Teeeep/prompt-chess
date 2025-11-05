require 'rails_helper'

RSpec.describe Match, type: :model do
  describe 'associations' do
    it 'belongs to agent' do
      expect(Match.reflect_on_association(:agent).macro).to eq(:belongs_to)
    end

    it 'has many moves with dependent destroy' do
      reflection = Match.reflect_on_association(:moves)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:dependent]).to eq(:destroy)
    end
  end

  describe 'validations' do
    let(:agent) { create(:agent) }

    it 'requires agent' do
      match = Match.new(stockfish_level: 5)
      expect(match).not_to be_valid
      expect(match.errors[:agent]).to be_present
    end

    it 'requires stockfish_level' do
      match = Match.new(agent: agent)
      expect(match).not_to be_valid
      expect(match.errors[:stockfish_level]).to be_present
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(Match.statuses).to eq({
        'pending' => 0,
        'in_progress' => 1,
        'completed' => 2,
        'errored' => 3
      })
    end

    it 'defines winner enum' do
      expect(Match.winners).to eq({
        'agent' => 0,
        'stockfish' => 1,
        'draw' => 2
      })
    end
  end

  describe 'defaults' do
    let(:agent) { create(:agent) }
    let(:match) { Match.create!(agent: agent, stockfish_level: 5) }

    it 'sets total_moves to 0' do
      expect(match.total_moves).to eq(0)
    end

    it 'sets total_tokens_used to 0' do
      expect(match.total_tokens_used).to eq(0)
    end

    it 'sets total_cost_cents to 0' do
      expect(match.total_cost_cents).to eq(0)
    end

    it 'sets status to pending' do
      expect(match.status).to eq('pending')
    end
  end

  describe 'stockfish_level validation' do
    let(:agent) { create(:agent) }

    it 'allows levels 1-8' do
      (1..8).each do |level|
        match = Match.new(agent: agent, stockfish_level: level)
        expect(match).to be_valid
      end
    end

    it 'rejects level 0' do
      match = Match.new(agent: agent, stockfish_level: 0)
      expect(match).not_to be_valid
      expect(match.errors[:stockfish_level]).to be_present
    end

    it 'rejects level 9' do
      match = Match.new(agent: agent, stockfish_level: 9)
      expect(match).not_to be_valid
      expect(match.errors[:stockfish_level]).to be_present
    end
  end
end
