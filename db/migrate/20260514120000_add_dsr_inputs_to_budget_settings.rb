class AddDsrInputsToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :annual_income, :integer
    add_column :budget_settings, :existing_debt_monthly, :integer
  end
end
