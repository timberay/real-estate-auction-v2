# frozen_string_literal: true

require "test_helper"

class PropertyCardComponentTest < ViewComponent::TestCase
  test "renders property case number" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_text property.case_number
  end

  test "price tooltips support click (mobile) in addition to hover (desktop) (C12)" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))

    # C12: hover doesn't exist on mobile, so the appraisal/min-bid tooltip
    # triggers must also fire on click. Keep the hover bindings so desktop
    # behavior is unchanged.
    tooltips = page.all("[data-controller='tooltip']")
    assert tooltips.any?, "expected at least one tooltip element in the card"
    tooltips.each do |el|
      action = el["data-action"].to_s
      assert_includes action, "mouseenter->tooltip#show",
        "tooltip must still respond to hover (desktop)"
      assert_includes action, "click->tooltip#toggleVisible",
        "tooltip must also respond to click for mobile (C12)"
    end
  end

  test "renders safety badge" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, safety_rating: "safe"))
    assert_selector ".inline-flex", text: "안전"
  end

  test "renders address" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_text property.address
  end

  test "renders court_name when present" do
    property = properties(:safe_apartment) # court_name: "서울중앙지방법원"
    render_inline(PropertyCardComponent.new(property: property))
    assert_text "서울중앙지방법원"
  end

  test "does not render court_name section when blank" do
    property = properties(:risky_villa) # court_name: nil
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_selector "[data-property-card='court']"
  end

  test "renders appraisal price label and value on separate line" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='appraisal']", text: "8억"
    assert_text "감정가"
  end

  test "renders min bid price with label 최저매각가" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='min-bid']", text: "5억 6,000만원"
    assert_text "최저매각가"
  end

  test "renders budget exceeded badge when min_bid_price exceeds max_bid_amount" do
    property = properties(:safe_apartment) # min_bid_price: 560000000 (5.6억원)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 50000)) # 5억만원
    assert_selector ".inline-flex", text: "예산 초과"
  end

  test "does not render budget exceeded badge when within budget" do
    property = properties(:safe_apartment) # min_bid_price: 560000000 (5.6억원)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 100000)) # 10억만원
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when min_bid_price within budget even if appraisal_price exceeds" do
    # Key behavior: a property with high appraisal but discounted min_bid (after 유찰) should NOT be flagged.
    property = properties(:safe_apartment) # appraisal_price: 8억, min_bid_price: 5.6억
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 70000)) # 7억만원
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when max_bid_amount is nil" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: nil))
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when max_bid_amount not provided" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_text "예산 초과"
  end

  test "renders AI analysis badge when analyzed is true" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, analyzed: true))
    assert_selector ".inline-flex", text: "AI 분석완료"
  end

  test "does not render AI analysis badge when analyzed is false" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, analyzed: false))
    assert_no_text "AI 분석완료"
  end

  test "does not render AI analysis badge when analyzed is not provided" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_text "AI 분석완료"
  end

  test "renders FavoriteToggleComponent when user_property is given" do
    up = user_properties(:guest_safe_apartment)
    render_inline(PropertyCardComponent.new(property: up.property, user_property: up))
    assert_selector "##{ActionView::RecordIdentifier.dom_id(up, :favorite_toggle)}"
  end

  test "does not render FavoriteToggleComponent when user_property is nil" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_selector "[id$='_favorite_toggle']"
  end

  test "renders next auction schedule row with D-day badge when future schedule exists" do
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0) do
      property = properties(:safe_apartment)
      property.auction_schedules.delete_all
      schedule_date = Date.current + 5.days
      property.auction_schedules.create!(schedule_date: schedule_date, schedule_time: "1000")

      render_inline(PropertyCardComponent.new(property: property))

      assert_selector "[data-property-card='next-auction']", text: "다음 매각기일"
      assert_selector "[data-property-card='next-auction']", text: schedule_date.strftime("%Y.%m.%d")
      assert_selector "[data-property-card='next-auction']", text: "D-5"
      assert_selector "[data-property-card='next-auction'] [aria-label='매각 5일 전']"
    end
  end

  test "uses red D-day styling when schedule is today" do
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0) do
      property = properties(:safe_apartment)
      property.auction_schedules.delete_all
      property.auction_schedules.create!(schedule_date: Date.current, schedule_time: "1000")

      render_inline(PropertyCardComponent.new(property: property))

      assert_selector "[data-property-card='next-auction'] .bg-red-100", text: "D-day"
    end
  end

  test "does not render next auction row when no future schedule exists" do
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0) do
      property = properties(:safe_apartment)
      property.auction_schedules.delete_all

      render_inline(PropertyCardComponent.new(property: property))

      assert_no_selector "[data-property-card='next-auction']"
      assert_no_text "다음 매각기일"
    end
  end

  test "does not render next auction row when only past schedules exist" do
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0) do
      property = properties(:safe_apartment)
      property.auction_schedules.delete_all
      property.auction_schedules.create!(schedule_date: Date.current - 30.days, schedule_time: "1000")

      render_inline(PropertyCardComponent.new(property: property))

      assert_no_selector "[data-property-card='next-auction']"
    end
  end

  # B29: 삭제 버튼은 더보기(overflow) 메뉴 안에 숨기고, confirm 카피를 부드럽게.
  test "renders overflow menu trigger button with aria-haspopup" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-controller~='overflow-menu'] button[aria-haspopup='true'][aria-expanded='false']"
  end

  test "overflow menu is initially hidden" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-overflow-menu-target='menu'][hidden]", visible: :all
  end

  test "delete form is inside the overflow menu, not at card level" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    # button_to renders a <form method="post"> with _method=delete; assert it lives inside the hidden menu.
    path = Rails.application.routes.url_helpers.property_path(property)
    assert_selector "[data-overflow-menu-target='menu'] form[action='#{path}'][method='post']", visible: :all
  end

  test "confirm message uses softened copy (B-37)" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    confirm = page.find("[data-overflow-menu-target='menu'] button[data-turbo-confirm]", visible: :all)["data-turbo-confirm"]
    assert_includes confirm, "내 메모, AI 분석 결과, 권리 보고서"
    assert_includes confirm, "되돌릴 수 없어요"
    assert_includes confirm, "계속하시겠습니까?"
  end

  test "confirm message no longer uses the old technical phrase" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    confirm = page.find("[data-overflow-menu-target='menu'] button[data-turbo-confirm]", visible: :all)["data-turbo-confirm"]
    refute_includes confirm, "저장된 분석 결과, 권리분석 보고서 등"
    refute_includes confirm, "복구할 수 없습니다"
  end
end
