# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, safety_rating: nil, max_bid_amount: nil, analyzed: false)
    @property = property
    @safety_rating = safety_rating
    @max_bid_amount = max_bid_amount
    @analyzed = analyzed
  end

  private

  def formatted_price(amount)
    helpers.format_price_won(amount)
  end

  def budget_exceeded?
    return false unless @max_bid_amount.present? && @property.min_bid_price.present?

    # max_bid_amount is in 만원 (from budget settings), property prices are in 원 (won)
    @property.min_bid_price > @max_bid_amount * 10000
  end
end
