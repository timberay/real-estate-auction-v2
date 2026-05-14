# T1.2-F-C — append-only audit row for a TransferTaxRate change.
# `transfer_tax_rate` is optional because destroyed rows must still
# leave an audit trail; `user` is mandatory because every admin action
# must be attributable.
class TransferTaxRateAuditLog < ApplicationRecord
  ACTIONS = %w[created updated destroyed].freeze

  belongs_to :user
  belongs_to :transfer_tax_rate, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :changes_json, presence: true
end
