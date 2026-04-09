class AddRegionToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :region, :string, default: "제주특별자치도"
  end
end
