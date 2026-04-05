class CreateBudgetSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :property_case_id
      t.integer :version, null: false
      t.references :parent_snapshot, foreign_key: { to_table: :budget_snapshots }
      t.string :trigger, null: false
      t.integer :available_cash
      t.string :property_type_name
      t.string :area_range
      t.string :area_unit
      t.integer :repair_cost
      t.integer :acquisition_tax
      t.integer :scrivener_fee
      t.integer :moving_cost
      t.integer :maintenance_fee
      t.string :loan_policy_name
      t.decimal :loan_ratio, precision: 3, scale: 2
      t.integer :max_bid_amount
      t.integer :failed_auction_rounds
      t.integer :searchable_appraisal_limit
      t.datetime :calculated_at, null: false
      t.timestamps
    end
    add_index :budget_snapshots, [ :user_id, :version ]
  end
end
