class RemoveAreaUnitFromBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :budget_settings, :area_unit, :string, default: "pyeong", null: false
  end
end
