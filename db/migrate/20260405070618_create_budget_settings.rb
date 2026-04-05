class CreateBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_settings do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :available_cash
      t.references :property_type, foreign_key: true
      t.integer :area_range_min
      t.integer :area_range_max
      t.integer :repair_cost
      t.integer :acquisition_tax
      t.integer :scrivener_fee
      t.integer :moving_cost
      t.integer :maintenance_fee
      t.references :loan_policy, foreign_key: true
      t.decimal :loan_ratio, precision: 3, scale: 2
      t.integer :max_bid_amount
      t.string :area_unit, null: false, default: "pyeong"
      t.integer :failed_auction_rounds, null: false, default: 0
      t.integer :searchable_appraisal_limit
      t.datetime :completed_at
      t.timestamps
    end
    add_index :budget_settings, :user_id, unique: true
  end
end
