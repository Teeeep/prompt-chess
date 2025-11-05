module Mutations
  class ClearApiConfig < BaseMutation
    description "Clear the current API configuration from session"

    field :success, Boolean, null: false,
      description: "Whether the configuration was cleared (always true)"

    def resolve
      LlmConfigService.clear(context[:session])
      { success: true }
    end
  end
end
