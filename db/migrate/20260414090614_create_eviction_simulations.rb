class CreateEvictionSimulations < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_simulations do |t|
      t.references :property, null: true, foreign_key: true
      t.string     :session_id
      t.json       :answers
      t.json       :result_path
      t.string     :difficulty_level
      t.boolean    :completed, default: false, null: false
      t.timestamps
    end

    add_index :eviction_simulations, :session_id
    add_index :eviction_simulations, [ :property_id ], unique: true, where: "property_id IS NOT NULL",
              name: "idx_eviction_simulations_one_per_property"
  end
end
