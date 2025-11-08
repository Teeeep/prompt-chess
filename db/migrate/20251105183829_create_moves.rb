class CreateMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :moves do |t|
      t.references :match, null: false, foreign_key: true
      t.integer :move_number, null: false
      t.integer :player, null: false
      t.string :move_notation, null: false
      t.text :board_state_before, null: false
      t.text :board_state_after, null: false
      t.text :llm_prompt
      t.text :llm_response
      t.integer :tokens_used
      t.integer :response_time_ms, null: false

      t.timestamps
    end

    add_index :moves, [ :match_id, :move_number ], unique: true
    add_index :moves, [ :match_id, :player ]
  end
end
