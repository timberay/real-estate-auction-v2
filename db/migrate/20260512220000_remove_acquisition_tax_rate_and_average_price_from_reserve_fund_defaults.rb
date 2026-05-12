class RemoveAcquisitionTaxRateAndAveragePriceFromReserveFundDefaults < ActiveRecord::Migration[8.0]
  def change
    remove_column :reserve_fund_defaults, :acquisition_tax_rate, :decimal,
                  precision: 5, scale: 4, null: false
    remove_column :reserve_fund_defaults, :average_price, :integer,
                  default: 0, null: false
  end
end
