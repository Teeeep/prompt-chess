require 'rails_helper'

RSpec.describe 'MatchRunner Broadcasting' do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }
  let(:session) { { llm_config: { provider: 'anthropic', api_key: 'test-key', model: 'claude-3-5-sonnet-20241022' } } }

  before do
    # Stub AgentMoveService to avoid API calls
    allow_any_instance_of(AgentMoveService).to receive(:generate_move).and_return({
      move: 'e4',
      prompt: 'Test prompt',
      response: 'Test response',
      tokens: 150,
      time_ms: 500
    })
  end

  describe 'subscription triggers' do
    it 'broadcasts after agent move' do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play only 1 move then end
      allow(runner).to receive(:game_over?).and_return(false, true)

      expect(PromptChessSchema.subscriptions).to receive(:trigger).with(
        :match_updated,
        { match_id: match.id.to_s },
        hash_including(:match, :latest_move)
      )

      runner.run!
    end

    it 'includes updated match and latest move in payload' do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play only 1 move
      allow(runner).to receive(:game_over?).and_return(false, true)

      expect(PromptChessSchema.subscriptions).to receive(:trigger) do |event, args, payload|
        expect(event).to eq(:match_updated)
        expect(args[:match_id]).to eq(match.id.to_s)
        expect(payload[:match]).to be_a(Match)
        expect(payload[:latest_move]).to be_a(Move)
      end

      runner.run!
    end

    it 'broadcasts final state on completion' do
      runner = MatchRunner.new(match: match, session: session)

      # Stub to play 1 move then end
      allow(runner).to receive(:game_over?).and_return(false, true)

      # Expect broadcast after move
      expect(PromptChessSchema.subscriptions).to receive(:trigger).once

      runner.run!

      match.reload
      expect(match.status).to eq('completed')
    end
  end
end
