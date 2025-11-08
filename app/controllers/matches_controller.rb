class MatchesController < ApplicationController
  def show
    @match = Match.includes(:agent, :moves).find(params[:id])
    @latest_agent_move = @match.moves.select { |m| m.player == "agent" }.max_by(&:move_number)
  end
end
