class AddAcquisitionTaxPreciseModeToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :acquisition_tax_precise_mode, :boolean, null: false, default: false
  end
end
