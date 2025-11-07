class MatchExecutionJob < ApplicationJob
  queue_as :default

  def perform(match_id, session)
    match = Match.find(match_id)

    # Run the match
    runner = MatchRunner.new(match: match, session: session)
    runner.run!
  rescue StandardError => e
    # Match error state is already set by MatchRunner
    # Re-raise for job retry logic
    raise
  end
end
