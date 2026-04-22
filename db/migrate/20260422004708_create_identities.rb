class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid,      null: false
      t.string :email
      t.text   :raw_info
      t.timestamps
    end

    add_index :identities, [ :provider, :uid ], unique: true
    add_index :identities, [ :user_id, :provider ]
  end
end
