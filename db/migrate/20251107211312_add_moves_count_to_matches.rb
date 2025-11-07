class AddMovesCountToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :moves_count, :integer, default: 0, null: false
  end
end
