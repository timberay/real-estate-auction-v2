class CreateApiCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :api_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider_name, null: false
      t.string :api_key
      t.string :api_secret
      t.boolean :enabled, default: true, null: false
      t.datetime :last_verified_at
      t.timestamps
    end
    add_index :api_credentials, [ :user_id, :provider_name ], unique: true
  end
end
