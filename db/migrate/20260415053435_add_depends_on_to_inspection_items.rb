class AddDependsOnToInspectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_items, :depends_on, :json
  end
end
