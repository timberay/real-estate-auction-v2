class DropBudgetSnapshots < ActiveRecord::Migration[8.1]
  def up
    drop_table :budget_snapshots
  end

  def down
    create_table :budget_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :version, null: false
      t.string :trigger
      t.integer :available_cash
      t.integer :repair_cost
      t.integer :acquisition_tax
      t.integer :scrivener_fee
      t.integer :moving_cost
      t.integer :maintenance_fee
      t.integer :total_reserves
      t.float :loan_ratio
      t.integer :max_bid_amount
      t.datetime :calculated_at
      t.references :parent_snapshot, foreign_key: { to_table: :budget_snapshots }
      t.timestamps
    end
  end
end
