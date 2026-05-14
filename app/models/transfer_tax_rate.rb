class TransferTaxRate < ApplicationRecord
  HOUSEHOLD_TIERS = AcquisitionTaxRate::HOUSEHOLD_TIERS
  HOLDING_PERIODS = %w[under_1y btw_1_2y over_2y].freeze

  belongs_to :property_type

  validates :household_tier, inclusion: { in: HOUSEHOLD_TIERS }
  validates :holding_period, inclusion: { in: HOLDING_PERIODS }
  validates :total_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
