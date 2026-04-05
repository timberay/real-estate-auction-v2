class CreateLoanPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :loan_policies do |t|
      t.references :property_type, null: false, foreign_key: true
      t.string :policy_name, null: false
      t.decimal :loan_ratio, null: false, precision: 3, scale: 2
      t.text :description
      t.string :source_url
      t.date :effective_date, null: false
      t.date :expiry_date
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :loan_policies, [ :property_type_id, :enabled ]
  end
end
