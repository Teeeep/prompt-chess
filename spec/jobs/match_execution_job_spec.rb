require 'rails_helper'

RSpec.describe MatchExecutionJob, type: :job do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, stockfish_level: 1) }
  let(:llm_config) { { provider: 'anthropic', api_key: ENV['ANTHROPIC_API_KEY'] || 'test-key', model: 'claude-3-5-haiku-20241022' } }

  describe '#perform' do
    it 'executes the match runner', vcr: { cassette_name: 'match_execution_job/success' } do
      # Stub to play short game
      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(false, false, true)

      MatchExecutionJob.perform_now(match.id, llm_config)

      match.reload
      expect(match.status).to eq('completed')
      expect(match.moves.count).to be > 0
    end

    it 'marks match as errored on failure' do
      # Trigger a real error that MatchRunner will catch
      allow_any_instance_of(AgentMoveService).to receive(:generate_move).and_raise(
        AgentMoveService::InvalidMoveError, 'Test error'
      )

      expect {
        MatchExecutionJob.perform_now(match.id, llm_config)
      }.to raise_error(AgentMoveService::InvalidMoveError)

      match.reload
      expect(match.status).to eq('errored')
      expect(match.error_message).to include('Test error')
    end

    it 'finds match by ID' do
      expect(Match).to receive(:find).with(match.id).and_call_original

      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(true)

      MatchExecutionJob.perform_now(match.id, llm_config)
    end

    it 'passes llm_config to MatchRunner as session' do
      expect(MatchRunner).to receive(:new).with(
        match: match,
        session: { llm_config: llm_config }
      ).and_call_original

      allow_any_instance_of(MatchRunner).to receive(:game_over?).and_return(true)

      MatchExecutionJob.perform_now(match.id, llm_config)
    end
  end

  describe 'job configuration' do
    it 'is enqueued on default queue' do
      expect(MatchExecutionJob.new.queue_name).to eq('default')
    end
  end
end
