class CreateUserProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :user_properties do |t|
      t.references :user, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :safety_rating
      t.datetime :analyzed_at
      t.timestamps
    end
    add_index :user_properties, [ :user_id, :property_id ], unique: true
  end
end
