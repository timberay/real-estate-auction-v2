# frozen_string_literal: true

require "test_helper"

class NearbyAuctionLinksComponentTest < ViewComponent::TestCase
  test "renders the 인근 매각가율 heading" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    assert_text "인근 매각가율"
  end

  test "renders link to 법원경매정보 criteria search" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    assert_selector "a[href='#{NearbyAuctionLinksComponent::COURT_SEARCH_URL}']"
    assert_match %r{\Ahttps://www\.courtauction\.go\.kr/},
                 NearbyAuctionLinksComponent::COURT_SEARCH_URL
  end

  test "external link opens in new tab with safe rel" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    link = page.find("a[href='#{NearbyAuctionLinksComponent::COURT_SEARCH_URL}']")
    assert_equal "_blank", link[:target]
    assert_includes link[:rel].to_s.split, "noopener"
    assert_includes link[:rel].to_s.split, "noreferrer"
  end

  test "renders new-window screen-reader hint for accessibility" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    assert_selector "span.sr-only", text: "(새 창)"
  end

  test "shows full region label when sido/sigungu/dong all present" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    assert_selector "[data-test='region-label']", text: "서울특별시 강남구 역삼동"
  end

  test "shows partial region label when dong is blank" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:unanalyzed_officetel)))
    assert_selector "[data-test='region-label']", text: "인천광역시 연수구"
  end

  test "omits region paragraph when all region fields are blank" do
    property = Property.new(
      case_number: "2026타경00001",
      sido: nil, sigungu: nil, dong: nil
    )
    render_inline(NearbyAuctionLinksComponent.new(property: property))
    assert_no_selector "[data-test='region-label']"
  end

  test "explains scope: this tool calculates cost/tax, external service shows sale-price stats" do
    render_inline(NearbyAuctionLinksComponent.new(property: properties(:safe_apartment)))
    assert_text "법원경매정보"
    assert_text "비용"
  end
end
