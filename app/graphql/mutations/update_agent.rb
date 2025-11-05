module Mutations
  class UpdateAgent < BaseMutation
    description "Update an existing agent"

    argument :id, ID, required: true
    argument :name, String, required: false
    argument :role, String, required: false
    argument :prompt_text, String, required: false
    argument :configuration, GraphQL::Types::JSON, required: false

    field :agent, Types::AgentType, null: true
    field :errors, [String], null: false

    def resolve(id:, **attributes)
      agent = Agent.find_by(id: id)

      if agent.nil?
        return { agent: nil, errors: ["Agent not found"] }
      end

      # Only pass the attributes that were provided
      update_params = attributes.compact

      if agent.update(update_params)
        { agent: agent, errors: [] }
      else
        { agent: nil, errors: agent.errors.full_messages }
      end
    end
  end
end
