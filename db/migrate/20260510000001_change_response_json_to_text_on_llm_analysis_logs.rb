class ChangeResponseJsonToTextOnLlmAnalysisLogs < ActiveRecord::Migration[8.1]
  def up
    change_column :llm_analysis_logs, :response_json, :text
  end

  def down
    change_column :llm_analysis_logs, :response_json, :json
  end
end
