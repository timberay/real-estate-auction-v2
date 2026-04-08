class AddYesMeansSafeToInspectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_items, :yes_means_safe, :boolean, null: false, default: true
  end
end
