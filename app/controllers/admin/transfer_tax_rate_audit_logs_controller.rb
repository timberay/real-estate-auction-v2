# T1.2-F-C — read-only viewer for the TransferTaxRate audit ledger.
# The list is admin-only (BaseController's `require_admin` returns 404
# to non-admins so the URL stays invisible). We cap at 100 rows for now;
# heavier filtering or pagination can land later if churn warrants it.
module Admin
  class TransferTaxRateAuditLogsController < BaseController
    def index
      @logs = TransferTaxRateAuditLog
        .includes(:user, :transfer_tax_rate)
        .order(created_at: :desc)
        .limit(100)
    end
  end
end
