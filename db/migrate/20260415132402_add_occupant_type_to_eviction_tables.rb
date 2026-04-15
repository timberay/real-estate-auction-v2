class AddOccupantTypeToEvictionTables < ActiveRecord::Migration[8.1]
  def change
    add_column :eviction_simulations, :occupant_type, :string
    add_column :eviction_steps, :occupant_type, :string
    add_column :eviction_simulator_questions, :occupant_type, :string

    add_index :eviction_steps, :occupant_type
    add_index :eviction_simulator_questions, :occupant_type
  end
end
