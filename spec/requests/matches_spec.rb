require 'rails_helper'

RSpec.describe "Matches", type: :request do
  describe "GET /matches/:id" do
    let(:agent) { create(:agent) }
    let(:match) { create(:match, agent: agent) }

    it "returns success" do
      get match_path(match)
      expect(response).to have_http_status(:success)
    end

    it "loads match with associations" do
      create(:move, :agent_move, match: match, move_number: 1)
      create(:move, :stockfish_move, match: match, move_number: 2)

      get match_path(match)

      expect(response).to have_http_status(:success)
      # Verify match data is present
      expect(response.body).to include("Match ##{match.id}")
      expect(response.body).to include(match.status.titleize)
    end
  end

  describe "GET /matches/:id with invalid id" do
    it "returns 404" do
      get "/matches/99999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
