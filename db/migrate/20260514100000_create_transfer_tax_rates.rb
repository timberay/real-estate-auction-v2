class CreateTransferTaxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :transfer_tax_rates do |t|
      t.references :property_type, null: false, foreign_key: true
      t.string  :household_tier, null: false
      t.string  :holding_period, null: false
      t.boolean :regulated_region
      t.decimal :total_rate, precision: 5, scale: 4, null: false
      t.timestamps
    end

    add_index :transfer_tax_rates,
              [ :property_type_id, :household_tier, :holding_period, :regulated_region ],
              name: "index_transfer_tax_rates_on_lookup"
  end
end
