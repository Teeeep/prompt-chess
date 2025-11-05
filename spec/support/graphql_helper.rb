module GraphqlHelper
  def execute_graphql(query, variables: {})
    post '/graphql', params: { query: query, variables: variables }
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include GraphqlHelper, type: :request
end
