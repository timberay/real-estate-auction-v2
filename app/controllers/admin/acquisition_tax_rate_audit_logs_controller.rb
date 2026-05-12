# F-D-3 — read-only viewer for the AcquisitionTaxRate audit ledger.
# The list is admin-only (BaseController's `require_admin` returns 404
# to non-admins so the URL stays invisible). We cap at 100 rows for now;
# heavier filtering or pagination can land later if churn warrants it.
module Admin
  class AcquisitionTaxRateAuditLogsController < BaseController
    def index
      @logs = AcquisitionTaxRateAuditLog
        .includes(:user, :acquisition_tax_rate)
        .order(created_at: :desc)
        .limit(100)
    end
  end
end
