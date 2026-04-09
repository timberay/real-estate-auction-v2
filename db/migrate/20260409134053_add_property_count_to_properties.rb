class AddPropertyCountToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :property_count, :integer, default: 1, null: false
  end
end
