class MatchExecutionJob < ApplicationJob
  queue_as :default

  def perform(match_id, llm_config)
    match = Match.find(match_id)

    # Reconstruct session with only llm_config
    session = { llm_config: llm_config }

    # Run the match
    runner = MatchRunner.new(match: match, session: session)
    runner.run!
  rescue StandardError => e
    # Match error state is already set by MatchRunner
    # Re-raise for job retry logic
    raise
  end
end
