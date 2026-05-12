class AddHouseholdTierAndAcquisitionTaxAutoToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :household_tier, :string, null: false, default: "homeless"
    add_column :budget_settings, :acquisition_tax_auto, :boolean, null: false, default: true
  end
end
