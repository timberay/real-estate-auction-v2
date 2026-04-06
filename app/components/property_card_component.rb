# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, safety_rating: nil)
    @property = property
    @safety_rating = safety_rating
  end

  private

  def formatted_price(amount)
    return "—" unless amount
    number_to_currency(amount, unit: "", precision: 0, delimiter: ",") + "만원"
  end
end
