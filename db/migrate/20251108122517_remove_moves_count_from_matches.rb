class RemoveMovesCountFromMatches < ActiveRecord::Migration[8.0]
  def change
    remove_column :matches, :moves_count, :integer
  end
end
