class AddUserConfirmedAtToRightsAnalysisReports < ActiveRecord::Migration[8.1]
  def change
    add_column :rights_analysis_reports, :user_confirmed_at, :datetime
  end
end
