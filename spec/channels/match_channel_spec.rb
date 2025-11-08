require "rails_helper"

RSpec.describe MatchChannel, type: :channel do
  let(:match) { create(:match) }

  it "subscribes to a stream for the match" do
    subscribe(match_id: match.id)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(match)
  end
end
