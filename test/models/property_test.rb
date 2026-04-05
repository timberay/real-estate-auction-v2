require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    property = Property.new(
      case_number: "2026타경12345",
      court_name: "서울중앙지방법원",
      address: "서울특별시 강남구 역삼동 123-45",
      appraisal_price: 50000,
      min_bid_price: 35000
    )
    assert property.valid?
  end

  test "case_number is required" do
    property = Property.new(case_number: nil)
    assert_not property.valid?
    assert_includes property.errors[:case_number], "can't be blank"
  end

  test "case_number must be unique" do
    Property.create!(case_number: "2026타경12345", court_name: "서울중앙", address: "서울시", appraisal_price: 50000, min_bid_price: 35000)
    duplicate = Property.new(case_number: "2026타경12345")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:case_number], "has already been taken"
  end

  test "safety_rating enum values" do
    property = properties(:safe_apartment)
    property.safety_rating = "safe"
    assert_equal "safe", property.safety_rating
    assert property.safe?

    property.safety_rating = "caution"
    assert property.caution?

    property.safety_rating = "danger"
    assert property.danger?
  end

  test "has_many property_check_results" do
    property = properties(:safe_apartment)
    assert_respond_to property, :property_check_results
  end

  test "safety_rating defaults to nil (unanalyzed)" do
    property = Property.new(case_number: "2026타경99999", court_name: "서울중앙", address: "서울시", appraisal_price: 50000, min_bid_price: 35000)
    assert_nil property.safety_rating
  end
end
