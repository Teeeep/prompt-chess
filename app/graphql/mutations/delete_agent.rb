module Mutations
  class DeleteAgent < BaseMutation
    description "Delete an agent"

    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [String], null: false

    def resolve(id:)
      agent = Agent.find_by(id: id)

      if agent.nil?
        return { success: false, errors: ["Agent not found"] }
      end

      if agent.destroy
        { success: true, errors: [] }
      else
        { success: false, errors: agent.errors.full_messages }
      end
    end
  end
end
