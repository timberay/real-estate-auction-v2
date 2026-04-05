class CreateReserveFundDefaults < ActiveRecord::Migration[8.1]
  def change
    create_table :reserve_fund_defaults do |t|
      t.references :property_type, null: false, foreign_key: true
      t.integer :area_range_min, null: false
      t.integer :area_range_max, null: false
      t.integer :repair_cost, null: false
      t.decimal :acquisition_tax_rate, null: false, precision: 5, scale: 4
      t.integer :scrivener_fee, null: false
      t.integer :moving_cost, null: false
      t.integer :maintenance_fee, null: false
      t.timestamps
    end
    add_index :reserve_fund_defaults, [:property_type_id, :area_range_min, :area_range_max],
              name: "idx_reserve_defaults_type_area", unique: true
  end
end
