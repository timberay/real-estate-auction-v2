# F-D-3 — append-only audit row for an AcquisitionTaxRate change.
# `acquisition_tax_rate` is optional because destroyed rows must still
# leave an audit trail; `user` is mandatory because every admin action
# must be attributable.
class AcquisitionTaxRateAuditLog < ApplicationRecord
  ACTIONS = %w[created updated destroyed].freeze

  belongs_to :user
  belongs_to :acquisition_tax_rate, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :changes_json, presence: true
end
