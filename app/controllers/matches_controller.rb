class MatchesController < ApplicationController
  def show
    @match = Match.includes(:agent, :moves).find(params[:id])
  end
end
