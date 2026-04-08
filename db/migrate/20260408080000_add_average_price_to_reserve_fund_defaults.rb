class AddAveragePriceToReserveFundDefaults < ActiveRecord::Migration[8.1]
  def change
    add_column :reserve_fund_defaults, :average_price, :integer, null: false, default: 0
  end
end
