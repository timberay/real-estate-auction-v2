require "test_helper"

class PropertySaleDetailTest < ActiveSupport::TestCase
  test "belongs to property" do
    detail = property_sale_details(:safe_apartment_detail)
    assert_equal properties(:safe_apartment), detail.property
  end

  test "can store non_extinguished_rights text" do
    detail = property_sale_details(:risky_villa_detail)
    assert detail.non_extinguished_rights.present?
    assert detail.non_extinguished_rights.include?("임차권등기")
  end
end
