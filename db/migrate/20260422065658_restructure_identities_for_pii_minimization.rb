class RestructureIdentitiesForPiiMinimization < ActiveRecord::Migration[8.1]
  def change
    remove_column :identities, :raw_info, :text
    add_column :identities, :email_verified, :boolean
  end
end
