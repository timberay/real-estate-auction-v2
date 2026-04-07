class AddUserToPropertyCheckResults < ActiveRecord::Migration[8.1]
  def up
    add_reference :property_check_results, :user, null: true, foreign_key: true
    guest = User.find_by(email: "guest@auction.local")
    if guest
      execute "UPDATE property_check_results SET user_id = #{guest.id} WHERE user_id IS NULL"
    end
    change_column_null :property_check_results, :user_id, false
    remove_index :property_check_results, name: "idx_check_results_property_item"
    add_index :property_check_results, [ :property_id, :checklist_item_id, :user_id ],
              unique: true, name: "idx_check_results_property_item_user"
  end

  def down
    remove_index :property_check_results, name: "idx_check_results_property_item_user"
    add_index :property_check_results, [ :property_id, :checklist_item_id ],
              unique: true, name: "idx_check_results_property_item"
    remove_reference :property_check_results, :user
  end
end
