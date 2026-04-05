class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :failed_auction_rounds, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3
  }
  validates :area_unit, inclusion: { in: %w[pyeong sqm] }

  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze

  def completed?
    completed_at.present?
  end

  def total_reserves
    RESERVE_FIELDS.sum { |field| public_send(field).to_i }
  end
end
