class AddUserNotesAndInspectionVisitedToUserProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :user_properties, :notes, :text
    add_column :user_properties, :inspection_visited_on, :date
  end
end
