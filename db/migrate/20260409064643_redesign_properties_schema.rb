class RedesignPropertiesSchema < ActiveRecord::Migration[8.1]
  def change
    # --- Alter properties table ---
    remove_column :properties, :court_name, :string

    change_column :properties, :appraisal_price, :bigint
    change_column :properties, :min_bid_price, :bigint

    add_column :properties, :case_type, :string
    add_column :properties, :claim_amount, :bigint
    add_column :properties, :property_usage_code, :string
    add_column :properties, :sido, :string
    add_column :properties, :sigungu, :string
    add_column :properties, :dong, :string
    add_column :properties, :building_name, :string
    add_column :properties, :building_detail, :string
    add_column :properties, :building_structure, :string
    add_column :properties, :exclusive_area, :decimal
    add_column :properties, :land_category, :string
    add_column :properties, :failed_bid_count, :integer, default: 0
    add_column :properties, :view_count, :integer, default: 0
    add_column :properties, :interest_count, :integer, default: 0
    add_column :properties, :latitude, :decimal, precision: 10, scale: 7
    add_column :properties, :longitude, :decimal, precision: 10, scale: 7
    add_column :properties, :special_conditions_code, :string
    add_column :properties, :remarks, :text

    add_index :properties, [ :sido, :sigungu, :dong ], name: "idx_properties_location"
    add_index :properties, :property_type

    # --- Create property_sale_details (1:1) ---
    create_table :property_sale_details do |t|
      t.references :property, null: false, foreign_key: true, index: { unique: true }
      t.text :non_extinguished_rights
      t.text :superficies_details
      t.text :specification_remarks
      t.string :senior_mortgage_basis
      t.text :goods_remarks
      t.date :dividend_demand_deadline
      t.text :share_description
      t.bigint :price_round_1
      t.bigint :price_round_2
      t.bigint :price_round_3
      t.bigint :price_round_4
      t.timestamps
    end

    # --- Create auction_schedules (1:N) ---
    create_table :auction_schedules do |t|
      t.references :property, null: false, foreign_key: true
      t.date :schedule_date
      t.string :schedule_time
      t.date :bid_start_date
      t.date :bid_end_date
      t.string :place
      t.string :schedule_type
      t.string :result_code
      t.bigint :min_price
      t.bigint :sale_amount
      t.timestamps
    end
    add_index :auction_schedules, [ :property_id, :schedule_date ]

    # --- Create land_details (1:N) ---
    create_table :land_details do |t|
      t.references :property, null: false, foreign_key: true
      t.string :land_type
      t.string :land_area
      t.string :land_category
      t.string :share_ratio
      t.string :address
      t.string :lot_number
      t.timestamps
    end

    # --- Create appraisal_points (1:N) ---
    create_table :appraisal_points do |t|
      t.references :property, null: false, foreign_key: true
      t.string :item_code
      t.text :content
      t.timestamps
    end
    add_index :appraisal_points, [ :property_id, :item_code ]
  end
end
