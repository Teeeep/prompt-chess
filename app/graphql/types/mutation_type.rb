# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
  end
end
