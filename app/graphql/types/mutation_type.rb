# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_agent, mutation: Mutations::CreateAgent
    field :update_agent, mutation: Mutations::UpdateAgent
    field :delete_agent, mutation: Mutations::DeleteAgent
    field :configure_anthropic_api, mutation: Mutations::ConfigureAnthropicApi
    field :configure_openai_api, mutation: Mutations::ConfigureOpenaiApi
    field :test_api_connection, mutation: Mutations::TestApiConnection
    field :clear_api_config, mutation: Mutations::ClearApiConfig
    field :create_match, mutation: Mutations::CreateMatch
    field :submit_move, mutation: Mutations::SubmitMove
  end
end
