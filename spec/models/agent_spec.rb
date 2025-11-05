require 'rails_helper'

RSpec.describe Agent, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      agent = build(:agent)
      expect(agent).to be_valid
    end

    describe 'name' do
      it 'is required' do
        agent = build(:agent, name: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("can't be blank")
      end

      it 'must be at least 1 character' do
        agent = build(:agent, name: '')
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("is too short (minimum is 1 character)")
      end

      it 'must be at most 100 characters' do
        agent = build(:agent, name: 'a' * 101)
        expect(agent).not_to be_valid
        expect(agent.errors[:name]).to include("is too long (maximum is 100 characters)")
      end

      it 'allows 100 characters' do
        agent = build(:agent, name: 'a' * 100)
        expect(agent).to be_valid
      end
    end

    describe 'prompt_text' do
      it 'is required' do
        agent = build(:agent, prompt_text: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("can't be blank")
      end

      it 'must be at least 10 characters' do
        agent = build(:agent, prompt_text: 'short')
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("is too short (minimum is 10 characters)")
      end

      it 'must be at most 10,000 characters' do
        agent = build(:agent, prompt_text: 'a' * 10_001)
        expect(agent).not_to be_valid
        expect(agent.errors[:prompt_text]).to include("is too long (maximum is 10000 characters)")
      end

      it 'allows 10,000 characters' do
        agent = build(:agent, prompt_text: 'a' * 10_000)
        expect(agent).to be_valid
      end
    end

    describe 'role' do
      it 'is optional' do
        agent = build(:agent, role: nil)
        expect(agent).to be_valid
      end

      it 'must be at most 50 characters if present' do
        agent = build(:agent, role: 'a' * 51)
        expect(agent).not_to be_valid
        expect(agent.errors[:role]).to include("is too long (maximum is 50 characters)")
      end

      it 'allows 50 characters' do
        agent = build(:agent, role: 'a' * 50)
        expect(agent).to be_valid
      end
    end

    describe 'configuration' do
      it 'defaults to empty hash' do
        agent = Agent.new(name: 'Test', prompt_text: 'Test prompt text here')
        expect(agent.configuration).to eq({})
      end

      it 'must be present' do
        agent = build(:agent, configuration: nil)
        expect(agent).not_to be_valid
        expect(agent.errors[:configuration]).to include("can't be blank")
      end

      it 'accepts valid JSON structure' do
        agent = build(:agent, configuration: { temperature: 0.8, max_tokens: 200 })
        expect(agent).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'creates valid agent with default factory' do
      agent = build(:agent)
      expect(agent).to be_valid
    end

    it 'creates valid agent with :opening trait' do
      agent = build(:agent, :opening)
      expect(agent).to be_valid
      expect(agent.role).to eq('opening')
    end

    it 'creates valid agent with :tactical trait' do
      agent = build(:agent, :tactical)
      expect(agent).to be_valid
      expect(agent.role).to eq('tactical')
    end

    it 'creates valid agent with :positional trait' do
      agent = build(:agent, :positional)
      expect(agent).to be_valid
      expect(agent.role).to eq('positional')
    end

    it 'creates valid agent with :minimal_config trait' do
      agent = build(:agent, :minimal_config)
      expect(agent).to be_valid
      expect(agent.configuration).to eq({})
    end
  end
end
