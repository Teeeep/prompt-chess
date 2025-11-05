# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :test_field, String, null: false,
      description: "A simple test query to verify GraphQL is working"

    def test_field
      "Hello from GraphQL!"
    end

    field :agents, [Types::AgentType], null: false,
      description: "Returns all agents"

    def agents
      Agent.all
    end

    field :agent, Types::AgentType, null: true,
      description: "Returns a single agent by ID" do
      argument :id, ID, required: true
    end

    def agent(id:)
      Agent.find_by(id: id)
    end

    field :current_llm_config, Types::LlmConfigType, null: true,
      description: "Returns current LLM configuration for this session"

    def current_llm_config
      config = LlmConfigService.current(context[:session])
      return nil unless config

      # Handle both symbol and string keys (session serialization converts symbols to strings)
      {
        provider: config[:provider] || config["provider"],
        model: config[:model] || config["model"],
        api_key_last_four: LlmConfigService.masked_key(context[:session]),
        configured_at: config[:configured_at] || config["configured_at"]
      }
    end

    field :match, Types::MatchType, null: true,
      description: "Find a match by ID" do
      argument :id, ID, required: true
    end

    def match(id:)
      Match.find_by(id: id)
    end

    field :matches, [Types::MatchType], null: false,
      description: "List matches with optional filters" do
      argument :agent_id, ID, required: false
      argument :status, Types::MatchStatusEnum, required: false
    end

    def matches(agent_id: nil, status: nil)
      scope = Match.includes(:agent).order(created_at: :desc)
      scope = scope.where(agent_id: agent_id) if agent_id
      scope = scope.where(status: status) if status
      scope
    end
  end
end
