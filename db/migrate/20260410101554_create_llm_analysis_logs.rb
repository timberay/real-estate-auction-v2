class CreateLlmAnalysisLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_analysis_logs do |t|
      t.references :property, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.text :system_prompt, null: false
      t.text :user_prompt, null: false
      t.json :response_json
      t.string :provider
      t.string :model
      t.integer :status, default: 0, null: false
      t.text :error_message
      t.datetime :executed_at

      t.timestamps
    end

    add_index :llm_analysis_logs, :status
    add_index :llm_analysis_logs, [:property_id, :status]
  end
end
