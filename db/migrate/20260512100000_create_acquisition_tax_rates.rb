class CreateAcquisitionTaxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :acquisition_tax_rates do |t|
      t.references :property_type, null: false, foreign_key: true
      t.string  :household_tier, null: false
      t.boolean :regulated_region
      t.integer :price_bucket_min_manwon, null: false, default: 0
      t.integer :price_bucket_max_manwon
      t.boolean :area_over_85
      t.decimal :total_rate, precision: 5, scale: 4, null: false
      t.timestamps
    end

    add_index :acquisition_tax_rates,
              [ :property_type_id, :household_tier, :regulated_region, :area_over_85 ],
              name: "index_acquisition_tax_rates_on_lookup"
  end
end
