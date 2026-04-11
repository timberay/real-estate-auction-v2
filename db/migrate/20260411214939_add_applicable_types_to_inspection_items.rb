class AddApplicableTypesToInspectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_items, :applicable_types, :json
  end
end
