module Mutations
  class CreateMatch < BaseMutation
    description "Create a new match between an agent and Stockfish"

    argument :agent_id, ID, required: true,
      description: "ID of the agent to play"
    argument :stockfish_level, Integer, required: true,
      description: "Stockfish difficulty level (1-8)"

    field :match, Types::MatchType, null: true
    field :errors, [ String ], null: false

    def resolve(agent_id:, stockfish_level:)
      agent = Agent.find_by(id: agent_id)
      errors = []

      unless agent
        errors << "Agent not found"
      end

      unless (1..8).include?(stockfish_level)
        errors << "Stockfish level must be between 1 and 8"
      end

      # Check if LLM is configured in session
      unless LlmConfigService.configured?(context[:session])
        errors << "Please configure your API credentials first"
      end

      return { match: nil, errors: errors } if errors.any?

      # Create match
      match = Match.create!(
        agent: agent,
        stockfish_level: stockfish_level,
        status: :pending
      )

      # Enqueue background job with only llm_config from session
      MatchExecutionJob.perform_later(match.id, context[:session][:llm_config])

      { match: match, errors: [] }
    end
  end
end
