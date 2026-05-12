# F-D-3 — append-only ledger of admin mutations on AcquisitionTaxRate.
# acquisition_tax_rate_id is intentionally NOT a foreign key: when a rate
# is destroyed we still want the audit row to survive (the row is the
# proof that the destroy happened). Lookups remain efficient via the
# composite index below.
class CreateAcquisitionTaxRateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :acquisition_tax_rate_audit_logs do |t|
      t.integer  :acquisition_tax_rate_id
      t.references :user, null: false, foreign_key: true
      t.string   :action,       null: false
      t.text     :changes_json, null: false
      t.datetime :created_at,   null: false
    end

    add_index :acquisition_tax_rate_audit_logs,
              [ :acquisition_tax_rate_id, :created_at ],
              name: "index_acq_tax_rate_audit_logs_on_rate_and_time"
    add_index :acquisition_tax_rate_audit_logs,
              [ :user_id, :created_at ],
              name: "index_acq_tax_rate_audit_logs_on_user_and_time"
  end
end
