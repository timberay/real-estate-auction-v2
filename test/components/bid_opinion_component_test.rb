require "test_helper"

class BidOpinionComponentTest < ViewComponent::TestCase
  test "renders safe verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능합니다"
  end

  test "renders danger verdict with unresolvable items" do
    risk_results = InspectionResult.where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
    render_inline(BidOpinionComponent.new(
      rating: :danger,
      report: rights_analysis_reports(:risky_villa_report),
      risk_results: risk_results.includes(:inspection_item),
      budget_setting: budget_settings(:completed),
      property: properties(:risky_villa)
    ))
    assert_text "입찰을 권하지 않습니다"
  end

  test "renders caution verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :caution,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능하나 확인 필요"
  end

  test "renders incomplete verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :incomplete,
      report: nil,
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "분석이 완료되지 않았습니다"
  end

  test "renders key figures table" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "감정가"
    assert_text "최저매각가격"
    assert_text "인수금액"
    assert_text "최대 입찰가"
  end

  test "renders without budget setting" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: nil,
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능합니다"
    assert_text "감정가"
  end
end
