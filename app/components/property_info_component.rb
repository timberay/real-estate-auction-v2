# frozen_string_literal: true

class PropertyInfoComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(property:)
    @property = property
  end

  private

  def fields
    [
      { label: "사건번호", value: @property.case_number },
      { label: "소재지", value: @property.address },
      { label: "물건유형", value: @property.property_type },
      { label: "감정가", value: format_price_won(@property.appraisal_price) },
      { label: "최저매각가격", value: format_price_won(@property.min_bid_price) },
      { label: "전용면적", value: @property.exclusive_area.present? ? "#{@property.exclusive_area}㎡" : "—" },
      { label: "유찰횟수", value: @property.failed_bid_count.present? ? "#{@property.failed_bid_count}회" : "0회" },
      { label: "청구금액", value: format_price_won(@property.claim_amount) }
    ]
  end
end
