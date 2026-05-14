class AddDepositRateToUserProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :user_properties, :deposit_rate, :decimal, precision: 5, scale: 2, default: 0.10, null: false
  end
end
