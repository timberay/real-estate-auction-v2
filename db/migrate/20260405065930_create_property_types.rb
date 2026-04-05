class CreatePropertyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :property_types do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :enabled, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :property_types, :code, unique: true
    add_index :property_types, [:enabled, :sort_order]
  end
end
