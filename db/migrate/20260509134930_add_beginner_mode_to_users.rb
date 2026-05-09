class AddBeginnerModeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :beginner_mode, :boolean, default: true, null: false
  end
end
