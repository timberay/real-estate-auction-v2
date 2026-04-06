# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, safety_rating: nil, max_bid_amount: nil)
    @property = property
    @safety_rating = safety_rating
    @max_bid_amount = max_bid_amount
  end

  private

  def formatted_price(amount)
    helpers.format_price_in_eok(amount)
  end

  def budget_exceeded?
    @max_bid_amount.present? && @property.appraisal_price.present? && @property.appraisal_price > @max_bid_amount
  end
end
