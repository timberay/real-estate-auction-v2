require "application_system_test_case"

class PropertyShowAuctionScheduleTest < ApplicationSystemTestCase
  setup do
    # Pin the clock so D-N strings stay stable regardless of when tests run.
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0)
    @user = users(:budget_user)
    sign_in_as(@user)

    # Build a property that lands on properties/show.html.erb:
    #   - analyzed? must be true (at least one InspectionResult)
    #   - user_property has no safety_rating and no analyzed_at, so PropertiesController#show
    #     does not redirect to grade/tab views.
    @property = Property.create!(
      case_number: "2026타경99500",
      court_name: "서울중앙지방법원",
      address: "서울특별시 종로구 청운동 1-1",
      appraisal_price: 500_000_000,
      min_bid_price: 350_000_000
    )
    UserProperty.find_or_create_by!(user: @user, property: @property)
    InspectionResult.create!(
      user: @user,
      property: @property,
      inspection_item: inspection_items(:rights_002),
      source_type: :manual,
      has_risk: false
    )
  end

  teardown do
    travel_back
  end

  test "property show page displays next auction date with D-day badge" do
    schedule_date = Date.current + 5.days
    @property.auction_schedules.create!(schedule_date: schedule_date, schedule_time: "1000")

    visit property_path(@property)

    assert_selector "[data-property-detail='next-auction']", text: "다음 매각기일"
    assert_selector "[data-property-detail='next-auction']", text: schedule_date.strftime("%Y.%m.%d")
    assert_selector "[data-property-detail='next-auction']", text: "D-5"
  end

  test "property show page omits next auction row when only past schedules exist" do
    @property.auction_schedules.create!(schedule_date: Date.current - 7.days, schedule_time: "1000")

    visit property_path(@property)

    assert_no_selector "[data-property-detail='next-auction']"
  end
end
