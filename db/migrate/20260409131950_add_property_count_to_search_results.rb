class AddPropertyCountToSearchResults < ActiveRecord::Migration[8.1]
  def change
    add_column :search_results, :property_count, :integer, default: 1, null: false
  end
end
