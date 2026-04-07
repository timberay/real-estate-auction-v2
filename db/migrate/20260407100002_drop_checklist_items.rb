class DropChecklistItems < ActiveRecord::Migration[8.1]
  def change
    drop_table :checklist_items
  end
end
