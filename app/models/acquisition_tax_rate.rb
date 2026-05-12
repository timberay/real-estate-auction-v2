class AcquisitionTaxRate < ApplicationRecord
  HOUSEHOLD_TIERS = %w[homeless single_home multi_home_2 multi_home_3plus].freeze

  belongs_to :property_type

  validates :household_tier, inclusion: { in: HOUSEHOLD_TIERS }
  validates :price_bucket_min_manwon, presence: true,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :total_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 0.20 }
end
