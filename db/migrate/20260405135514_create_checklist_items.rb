class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items do |t|
      t.string :code, null: false
      t.string :category, null: false
      t.integer :risk_axis, null: false
      t.text :question, null: false
      t.text :description
      t.json :logic
      t.string :data_source_name
      t.string :priority, null: false, default: "상"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :checklist_items, :code, unique: true
    add_index :checklist_items, :risk_axis
    add_index :checklist_items, :position
  end
end
