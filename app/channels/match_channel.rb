class MatchChannel < ApplicationCable::Channel
  def subscribed
    match = Match.find(params[:match_id])
    stream_for match
  end

  def unsubscribed
    stop_all_streams
  end
end
