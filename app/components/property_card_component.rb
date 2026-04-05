# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
  end

  private

  def formatted_price(amount)
    return "—" unless amount
    number_to_currency(amount, unit: "", precision: 0, delimiter: ",") + "만원"
  end
end
