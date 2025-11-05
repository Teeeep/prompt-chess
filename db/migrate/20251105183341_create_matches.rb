class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :agent, null: false, foreign_key: true, index: true
      t.integer :stockfish_level, null: false
      t.integer :status, null: false, default: 0
      t.integer :winner
      t.string :result_reason
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_moves, null: false, default: 0
      t.string :opening_name
      t.integer :total_tokens_used, null: false, default: 0
      t.integer :total_cost_cents, null: false, default: 0
      t.integer :average_move_time_ms
      t.text :final_board_state
      t.text :error_message

      t.timestamps
    end

    add_index :matches, :status
    add_index :matches, :created_at
  end
end
