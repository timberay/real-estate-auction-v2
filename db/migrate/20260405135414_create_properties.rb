class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.string :case_number, null: false
      t.string :court_name
      t.string :property_type
      t.string :address
      t.integer :appraisal_price
      t.integer :min_bid_price
      t.string :status
      t.integer :safety_rating
      t.json :raw_data
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :properties, :case_number, unique: true
    add_index :properties, :safety_rating
  end
end
