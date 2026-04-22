class RestructureUsersForOauth < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.remove :password_digest, type: :string
      t.string   :name
      t.string   :avatar_url
      t.boolean  :guest,             null: false, default: true
      t.string   :guest_token
      t.datetime :last_seen_at
      t.datetime :terms_accepted_at
      t.change   :email, :string, null: true
    end

    remove_index :users, :email if index_exists?(:users, :email)
    add_index :users, :guest_token, unique: true
    add_index :users, :email,
      unique: true,
      where: "guest = 0 AND email IS NOT NULL",
      name: "index_users_on_email_when_account"
    add_index :users, [ :guest, :last_seen_at ]
  end
end
