class CreateInspectionResultVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_result_versions do |t|
      t.references :inspection_result, null: false, foreign_key: true
      t.integer  :version_number,  null: false
      t.integer  :source_type
      t.boolean  :has_risk
      t.json     :evidence
      t.text     :resolution_note
      t.datetime :snapshotted_at,  null: false
      t.timestamps
    end

    add_index :inspection_result_versions,
              [ :inspection_result_id, :version_number ],
              unique: true,
              name: "idx_inspection_result_versions_unique"
  end
end
