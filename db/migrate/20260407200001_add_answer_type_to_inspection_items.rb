class AddAnswerTypeToInspectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_items, :answer_type, :string
  end
end
