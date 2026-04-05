class CreatePropertyCheckResults < ActiveRecord::Migration[8.1]
  def change
    create_table :property_check_results do |t|
      t.references :property, null: false, foreign_key: true
      t.references :checklist_item, null: false, foreign_key: true
      t.integer :source_type
      t.text :api_value
      t.text :manual_value
      t.boolean :has_risk
      t.boolean :resolvable
      t.text :resolution_note
      t.timestamps
    end
    add_index :property_check_results, [ :property_id, :checklist_item_id ], unique: true, name: "idx_check_results_property_item"
  end
end
