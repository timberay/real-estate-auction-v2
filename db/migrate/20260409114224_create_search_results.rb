class CreateSearchResults < ActiveRecord::Migration[8.1]
  def change
    create_table :search_results do |t|
      t.references :user, null: false, foreign_key: true
      t.string :case_number, null: false
      t.string :court_name
      t.string :address
      t.integer :appraisal_price
      t.integer :min_bid_price
      t.string :property_type
      t.string :status
      t.integer :failed_bid_count
      t.string :auction_date
      t.string :remarks
      t.timestamps
    end

    add_index :search_results, [ :user_id, :case_number ], unique: true
  end
end
