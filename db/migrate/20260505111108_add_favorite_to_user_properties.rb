class AddFavoriteToUserProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :user_properties, :favorite, :boolean, default: false, null: false
    add_index :user_properties, [:user_id, :favorite, :created_at],
              name: "index_user_properties_on_user_favorite_created"
  end
end
