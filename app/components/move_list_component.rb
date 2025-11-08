class MoveListComponent < ViewComponent::Base
  def initialize(match:)
    @match = match
  end

  def move_pairs
    @match.moves.order(:move_number).each_slice(2).with_index(1)
  end
end
