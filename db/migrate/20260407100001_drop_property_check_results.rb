class DropPropertyCheckResults < ActiveRecord::Migration[8.1]
  def change
    drop_table :property_check_results
  end
end
