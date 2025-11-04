require 'rails_helper'

RSpec.describe 'GraphQL API', type: :request do
  describe 'POST /graphql' do
    it 'returns successful response for test field query' do
      post '/graphql', params: { query: '{ testField }' }

      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json['data']).to be_present
      expect(json['data']['testField']).to eq('Hello from GraphQL!')
    end

    it 'returns error for invalid query' do
      post '/graphql', params: { query: '{ invalidField }' }

      expect(response).to have_http_status(:success) # GraphQL returns 200 even for errors

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
    end
  end
end
