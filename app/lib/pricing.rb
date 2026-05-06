module Pricing
  MIN_BID_PRICE_WON = 50_000_000
  DEFAULT_MAX_PRICE_WON = 500_000_000

  # Canonical price tiers used in budget UI dropdowns and to round
  # user-supplied max-bid amounts up to the nearest court auction filter
  # value. Values are in Korean won.
  PRICE_TIERS_WON = [
    10_000_000, 50_000_000, 100_000_000, 150_000_000,
    200_000_000, 250_000_000, 300_000_000, 350_000_000,
    400_000_000, 450_000_000, 500_000_000, 550_000_000,
    600_000_000, 650_000_000, 700_000_000, 750_000_000,
    800_000_000, 850_000_000, 900_000_000, 950_000_000,
    1_000_000_000
  ].freeze

  # The criteria search has a hardcoded MIN_BID_PRICE filter (50M won), so a
  # max-filter below that would yield an empty range. Drop the 10M tier when
  # computing the max-filter for that endpoint.
  CRITERIA_MAX_FILTER_TIERS_WON = PRICE_TIERS_WON.drop(1).freeze

  module_function

  # First tier strictly greater than `amount`, or the highest tier if
  # `amount` is at/above the cap.
  def next_tier(amount, tiers: PRICE_TIERS_WON)
    tiers.find { |t| t > amount } || tiers.last
  end
end
