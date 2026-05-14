class CreateTransferTaxRateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :transfer_tax_rate_audit_logs do |t|
      # Nullable so destroyed rows can still leave a trail.
      t.integer :transfer_tax_rate_id
      t.string :action, null: false
      t.text :changes_json, null: false
      t.references :user, null: false, foreign_key: true

      t.datetime :created_at, null: false
    end

    add_index :transfer_tax_rate_audit_logs,
      [ :transfer_tax_rate_id, :created_at ],
      name: "index_xfer_tax_rate_audit_logs_on_rate_and_time"
    add_index :transfer_tax_rate_audit_logs,
      [ :user_id, :created_at ],
      name: "index_xfer_tax_rate_audit_logs_on_user_and_time"
  end
end
