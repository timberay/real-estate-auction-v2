class CreateInspectionResults < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_results do |t|
      t.references :property,        null: false, foreign_key: true
      t.references :inspection_item, null: false, foreign_key: true
      t.references :user,            null: false, foreign_key: true
      t.integer    :source_type
      t.boolean    :has_risk
      t.boolean    :resolvable
      t.text       :resolution_note
      t.text       :auto_value
      t.text       :manual_value
      t.timestamps
    end
    add_index :inspection_results,
              [ :property_id, :inspection_item_id, :user_id ],
              unique: true,
              name: "idx_inspection_results_unique"
  end
end
