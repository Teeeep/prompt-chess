require "rails_helper"

RSpec.describe "SubmitMove mutation", type: :request do
  let(:agent) { create(:agent) }
  let(:match) { create(:match, agent: agent, status: :in_progress) }

  let(:mutation) do
    <<~GQL
      mutation($matchId: ID!, $moveNotation: String!) {
        submitMove(input: {matchId: $matchId, moveNotation: $moveNotation}) {
          success
          move {
            id
            moveNotation
            player
          }
          error
        }
      }
    GQL
  end

  describe "valid move submission" do
    it "creates a move record" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "e4"
      }

      expect {
        post "/graphql", params: { query: mutation, variables: variables.to_json }
      }.to change(Move, :count).by(1)

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be true
      expect(data["move"]["moveNotation"]).to eq("e4")
      expect(data["move"]["player"]).to eq("AGENT")
      expect(data["error"]).to be_nil
    end
  end

  describe "invalid move notation" do
    it "returns error without creating move" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "z99"
      }

      expect {
        post "/graphql", params: { query: mutation, variables: variables.to_json }
      }.not_to change(Move, :count)

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["move"]).to be_nil
      expect(data["error"]).to include("Invalid move")
    end
  end

  describe "wrong turn" do
    let!(:last_move) { create(:move, :agent_move, match: match, move_number: 1) }

    it "returns error when it's not agent's turn" do
      variables = {
        matchId: match.id.to_s,
        moveNotation: "e4"
      }

      post "/graphql", params: { query: mutation, variables: variables.to_json }

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["error"]).to eq("Not your turn")
    end
  end

  describe "completed match" do
    let(:completed_match) { create(:match, agent: agent, status: :completed) }

    it "returns error for completed match" do
      variables = {
        matchId: completed_match.id.to_s,
        moveNotation: "e4"
      }

      post "/graphql", params: { query: mutation, variables: variables.to_json }

      json = JSON.parse(response.body)
      data = json.dig("data", "submitMove")

      expect(data["success"]).to be false
      expect(data["error"]).to eq("Match already completed")
    end
  end
end
