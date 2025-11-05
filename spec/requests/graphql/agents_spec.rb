require 'rails_helper'

RSpec.describe 'Agents GraphQL API', type: :request do
  describe 'Query: agents' do
    it 'returns all agents' do
      agent1 = create(:agent, name: 'Agent 1')
      agent2 = create(:agent, name: 'Agent 2')

      query = <<~GQL
        query {
          agents {
            id
            name
            role
            promptText
            configuration
          }
        }
      GQL

      result = execute_graphql(query)

      expect(result['data']['agents'].length).to eq(2)
      expect(result['data']['agents'].map { |a| a['name'] }).to contain_exactly('Agent 1', 'Agent 2')
    end

    it 'returns empty array when no agents exist' do
      query = <<~GQL
        query {
          agents {
            id
            name
          }
        }
      GQL

      result = execute_graphql(query)

      expect(result['data']['agents']).to eq([])
    end

    it 'includes all agent fields' do
      agent = create(:agent, :tactical)

      query = <<~GQL
        query {
          agents {
            id
            name
            role
            promptText
            configuration
            createdAt
            updatedAt
          }
        }
      GQL

      result = execute_graphql(query)
      agent_data = result['data']['agents'].first

      expect(agent_data['id']).to eq(agent.id.to_s)
      expect(agent_data['name']).to eq(agent.name)
      expect(agent_data['role']).to eq(agent.role)
      expect(agent_data['promptText']).to eq(agent.prompt_text)
      expect(agent_data['configuration']).to eq(agent.configuration.stringify_keys)
      expect(agent_data['createdAt']).to be_present
      expect(agent_data['updatedAt']).to be_present
    end
  end

  describe 'Query: agent' do
    it 'returns agent by ID' do
      agent = create(:agent, name: 'Test Agent')

      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
            role
            promptText
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: agent.id.to_s })

      expect(result['data']['agent']['id']).to eq(agent.id.to_s)
      expect(result['data']['agent']['name']).to eq('Test Agent')
    end

    it 'returns null for non-existent ID' do
      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: '99999' })

      expect(result['data']['agent']).to be_nil
    end

    it 'includes all agent fields' do
      agent = create(:agent, :opening)

      query = <<~GQL
        query($id: ID!) {
          agent(id: $id) {
            id
            name
            role
            promptText
            configuration
            createdAt
            updatedAt
          }
        }
      GQL

      result = execute_graphql(query, variables: { id: agent.id.to_s })
      agent_data = result['data']['agent']

      expect(agent_data['id']).to eq(agent.id.to_s)
      expect(agent_data['name']).to eq(agent.name)
      expect(agent_data['role']).to eq('opening')
      expect(agent_data['promptText']).to eq(agent.prompt_text)
      expect(agent_data['configuration']).to eq(agent.configuration.stringify_keys)
      expect(agent_data['createdAt']).to be_present
      expect(agent_data['updatedAt']).to be_present
    end
  end

  describe 'Mutation: createAgent' do
    context 'with valid params' do
      it 'creates agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
                name
                role
                promptText
                configuration
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Tactical Master',
            role: 'tactical',
            promptText: 'You are a tactical chess master who excels at finding combinations.',
            configuration: { temperature: 0.8, max_tokens: 600 }
          }
        }

        expect {
          execute_graphql(query, variables: variables)
        }.to change(Agent, :count).by(1)

        result = execute_graphql(query, variables: variables)
        agent_data = result['data']['createAgent']['agent']

        expect(agent_data['name']).to eq('Tactical Master')
        expect(agent_data['role']).to eq('tactical')
        expect(agent_data['promptText']).to eq('You are a tactical chess master who excels at finding combinations.')
        expect(agent_data['configuration']['temperature']).to eq('0.8')
        expect(agent_data['configuration']['max_tokens']).to eq('600')
      end

      it 'returns created agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
                name
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text for the agent.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']).to be_present
        expect(result['data']['createAgent']['agent']['name']).to eq('Test Agent')
      end

      it 'returns empty errors array' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text here.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['errors']).to eq([])
      end

      it 'sets default configuration if not provided' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                configuration
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: 'Test Agent',
            promptText: 'Test prompt text.'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']['configuration']).to eq({})
      end
    end

    context 'with invalid params' do
      it 'does not create agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'short'
          }
        }

        expect {
          execute_graphql(query, variables: variables)
        }.not_to change(Agent, :count)
      end

      it 'returns null agent' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'bad'
          }
        }

        result = execute_graphql(query, variables: variables)

        expect(result['data']['createAgent']['agent']).to be_nil
      end

      it 'returns validation errors' do
        query = <<~GQL
          mutation($input: CreateAgentInput!) {
            createAgent(input: $input) {
              agent {
                id
              }
              errors
            }
          }
        GQL

        variables = {
          input: {
            name: '',
            promptText: 'short'
          }
        }

        result = execute_graphql(query, variables: variables)

        errors = result['data']['createAgent']['errors']
        expect(errors).to include(match(/Name is too short/))
        expect(errors).to include(match(/Prompt text is too short/))
      end
    end
  end
end
