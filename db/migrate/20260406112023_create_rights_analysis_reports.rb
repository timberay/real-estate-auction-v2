class CreateRightsAnalysisReports < ActiveRecord::Migration[8.1]
  def change
    create_table :rights_analysis_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.string :base_right_type
      t.date :base_right_date
      t.string :base_right_holder
      t.integer :assumed_amount, default: 0, null: false
      t.integer :total_risk_amount, default: 0, null: false
      t.integer :verdict, default: 0, null: false
      t.text :verdict_summary
      t.string :opportunity_type
      t.text :opportunity_reason
      t.boolean :source_doc_reviewed, default: false, null: false
      t.datetime :analyzed_at, null: false
      t.json :report_data
      t.timestamps
    end
    add_index :rights_analysis_reports, [ :user_id, :property_id ], unique: true, name: "idx_rights_reports_user_property"
  end
end
