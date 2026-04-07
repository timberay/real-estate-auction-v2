class CreateInspectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_items do |t|
      t.string  :code,             null: false
      t.integer :tab,              null: false
      t.integer :tab_position,     null: false, default: 0
      t.string  :category,         null: false
      t.text    :question,         null: false
      t.text    :description
      t.json    :logic
      t.string  :data_source_name
      t.string  :priority,         null: false, default: "상"
      t.string  :merged_from
      t.timestamps
    end
    add_index :inspection_items, :code, unique: true
    add_index :inspection_items, [ :tab, :tab_position ]
  end
end
