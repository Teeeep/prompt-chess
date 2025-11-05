# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
    field :delete_agent, mutation: Mutations::DeleteAgent
    field :configure_anthropic_api, mutation: Mutations::ConfigureAnthropicApi
  end
end
