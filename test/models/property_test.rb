require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    property = Property.new(
      case_number: "2026타경12345",
      address: "서울특별시 강남구 역삼동 123-45",
      appraisal_price: 500000000,
      min_bid_price: 350000000
    )
    assert property.valid?
  end

  test "case_number is required" do
    property = Property.new(case_number: nil)
    assert_not property.valid?
    assert_includes property.errors[:case_number], "can't be blank"
  end

  test "case_number must be unique" do
    Property.create!(case_number: "2026타경12345", address: "서울시", appraisal_price: 500000000, min_bid_price: 350000000)
    duplicate = Property.new(case_number: "2026타경12345")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:case_number], "has already been taken"
  end

  test "has_one sale_detail" do
    property = properties(:safe_apartment)
    assert_respond_to property, :sale_detail
    assert_instance_of PropertySaleDetail, property.sale_detail
  end

  test "has_many auction_schedules" do
    property = properties(:safe_apartment)
    assert_respond_to property, :auction_schedules
    assert property.auction_schedules.count > 0
  end

  test "has_many land_details" do
    property = properties(:safe_apartment)
    assert_respond_to property, :land_details
  end

  test "has_many appraisal_points" do
    property = properties(:safe_apartment)
    assert_respond_to property, :appraisal_points
    assert property.appraisal_points.count > 0
  end

  test "has_many inspection_results" do
    property = properties(:safe_apartment)
    assert_respond_to property, :inspection_results
  end

  test "has_many user_properties" do
    property = properties(:safe_apartment)
    assert_respond_to property, :user_properties
  end

  test "destroying property cascades to sale_detail" do
    property = properties(:safe_apartment)
    detail_id = property.sale_detail.id
    property.destroy
    assert_nil PropertySaleDetail.find_by(id: detail_id)
  end
end
