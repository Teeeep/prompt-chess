class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      t.string :name, null: false
      t.string :role
      t.text :prompt_text, null: false
      t.jsonb :configuration, default: {}, null: false

      t.timestamps
    end

    add_index :agents, :role
  end
end
