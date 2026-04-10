class AddEvidenceToInspectionResults < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_results, :evidence, :json
  end
end
