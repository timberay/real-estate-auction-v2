class DropRemovedTablesAndColumns < ActiveRecord::Migration[8.1]
  def up
    drop_table :property_sale_details, if_exists: true
    drop_table :land_details, if_exists: true
    drop_table :appraisal_points, if_exists: true

    remove_column :properties, :raw_data, if_exists: true
  end

  def down
    create_table :property_sale_details do |t|
      t.references :property, null: false, index: { unique: true }
      t.text :non_extinguished_rights
      t.text :specification_remarks
      t.text :goods_remarks
      t.text :superficies_details
      t.string :senior_mortgage_basis
      t.text :share_description
      t.bigint :price_round_1
      t.bigint :price_round_2
      t.bigint :price_round_3
      t.bigint :price_round_4
      t.date :dividend_demand_deadline
      t.timestamps
    end

    create_table :land_details do |t|
      t.references :property, null: false, index: true
      t.string :land_type
      t.string :land_area
      t.string :land_category
      t.string :share_ratio
      t.string :address
      t.string :lot_number
      t.timestamps
    end

    create_table :appraisal_points do |t|
      t.references :property, null: false, index: true
      t.string :item_code
      t.text :content
      t.timestamps
      t.index [ :property_id, :item_code ]
    end

    add_column :properties, :raw_data, :json
  end
end
