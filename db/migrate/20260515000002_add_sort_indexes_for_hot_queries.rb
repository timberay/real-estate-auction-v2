class AddSortIndexesForHotQueries < ActiveRecord::Migration[8.1]
  def change
    add_index :llm_analysis_logs, :executed_at
    add_index :properties, :created_at
  end
end
