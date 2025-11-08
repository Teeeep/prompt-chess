module Mutations
  class CreateAgent < BaseMutation
    description "Create a new agent"

    argument :name, String, required: true
    argument :role, String, required: false
    argument :prompt_text, String, required: true
    argument :configuration, GraphQL::Types::JSON, required: false

    field :agent, Types::AgentType, null: true
    field :errors, [ String ], null: false

    def resolve(name:, prompt_text:, role: nil, configuration: nil)
      agent = Agent.new(
        name: name,
        prompt_text: prompt_text,
        role: role,
        configuration: configuration || {}
      )

      if agent.save
        { agent: agent, errors: [] }
      else
        { agent: nil, errors: agent.errors.full_messages }
      end
    end
  end
end
