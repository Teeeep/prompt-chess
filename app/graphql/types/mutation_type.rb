# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
  end
end
