class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
    add_index :users, :admin, where: "admin = 1", name: "index_users_on_admin_when_true"
  end
end
