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
    assert_includes property.errors[:case_number], "을(를) 입력해 주세요"
  end

  test "case_number must be unique" do
    Property.create!(case_number: "2026타경12345", address: "서울시", appraisal_price: 500000000, min_bid_price: 350000000)
    duplicate = Property.new(case_number: "2026타경12345")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:case_number], "은(는) 이미 사용 중입니다"
  end

  test "has_many auction_schedules" do
    property = properties(:safe_apartment)
    assert_respond_to property, :auction_schedules
    assert property.auction_schedules.count > 0
  end

  test "has_many inspection_results" do
    property = properties(:safe_apartment)
    assert_respond_to property, :inspection_results
  end

  test "has_many user_properties" do
    property = properties(:safe_apartment)
    assert_respond_to property, :user_properties
  end

  test "analyzed? returns true when inspection_results exist" do
    property = properties(:safe_apartment)
    assert property.analyzed?
  end

  test "analyzed? returns false when no inspection_results exist" do
    property = properties(:unanalyzed_officetel)
    assert_not property.analyzed?
  end

  # T1.4(b) — 차회 매각가 자동 계산: 한국 법원경매 표준 8할 저감.
  # 다음 회차 최저가 = (현재 최저가 × 0.8) 만원 단위 절사.
  test "next_round_min_bid_price returns 80% of min_bid_price floored to 만원" do
    property = Property.new(min_bid_price: 350_000_000) # 3.5억
    # 350M * 0.8 = 280M (정확히 만원 단위 떨어짐)
    assert_equal 280_000_000, property.next_round_min_bid_price
  end

  test "next_round_min_bid_price floors to 만원 (10,000원) granularity" do
    property = Property.new(min_bid_price: 333_333_333)
    # 333,333,333 * 0.8 = 266,666,666.4 → 만원 단위 절사 → 266,660,000
    assert_equal 266_660_000, property.next_round_min_bid_price
  end

  test "next_round_min_bid_price returns nil when min_bid_price is nil" do
    property = Property.new(min_bid_price: nil)
    assert_nil property.next_round_min_bid_price
  end

  test "next_round_min_bid_price returns nil when min_bid_price is zero" do
    property = Property.new(min_bid_price: 0)
    assert_nil property.next_round_min_bid_price
  end

  test "NEXT_ROUND_REDUCTION_RATE constant is 0.80" do
    assert_equal 0.80, Property::NEXT_ROUND_REDUCTION_RATE
  end

  # T3.1 — property_type categorization

  test "usage_category classifies 아파트 as :residential" do
    assert_equal :residential, Property.new(property_type: "아파트").usage_category
  end

  test "usage_category classifies 빌라/다세대 as :residential" do
    assert_equal :residential, Property.new(property_type: "빌라").usage_category
    assert_equal :residential, Property.new(property_type: "다세대주택").usage_category
  end

  test "usage_category classifies 단독주택/연립주택 as :residential" do
    assert_equal :residential, Property.new(property_type: "단독주택").usage_category
    assert_equal :residential, Property.new(property_type: "연립주택").usage_category
  end

  test "usage_category classifies 오피스텔 as :officetel" do
    assert_equal :officetel, Property.new(property_type: "오피스텔").usage_category
  end

  test "usage_category classifies 상가/근린상가 as :commercial" do
    assert_equal :commercial, Property.new(property_type: "상가").usage_category
    assert_equal :commercial, Property.new(property_type: "근린상가").usage_category
  end

  test "usage_category classifies 토지/대지/임야 as :land" do
    assert_equal :land, Property.new(property_type: "토지").usage_category
    assert_equal :land, Property.new(property_type: "대지").usage_category
    assert_equal :land, Property.new(property_type: "임야").usage_category
  end

  test "usage_category returns :unknown for unrecognized types" do
    assert_equal :unknown, Property.new(property_type: "기타").usage_category
  end

  test "usage_category returns :residential when property_type is blank (conservative default)" do
    assert_equal :residential, Property.new(property_type: nil).usage_category
    assert_equal :residential, Property.new(property_type: "").usage_category
  end

  test "residential? is true for :residential" do
    assert Property.new(property_type: "아파트").residential?
  end

  test "residential? is false for :officetel / :commercial / :land" do
    [ "오피스텔", "상가", "토지" ].each do |t|
      assert_not Property.new(property_type: t).residential?, "#{t} should not be residential"
    end
  end
end
