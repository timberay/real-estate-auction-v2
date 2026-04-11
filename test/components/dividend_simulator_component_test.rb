require "test_helper"

class DividendSimulatorComponentTest < ViewComponent::TestCase
  test "renders bid input form with manwon unit" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "user_simulation" => {} }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_selector "input[name='expected_bid']", visible: false
    assert_text "예상 낙찰가"
    assert_text "만원"
  end

  test "renders distribution table when simulation exists" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    report.report_data = {
      "user_simulation" => {
        "expected_bid" => 15000,
        "distribution" => [
          { "priority" => 0, "holder" => "경매 비용", "type" => "경매 비용", "claim" => 300, "dividend" => 300, "shortfall" => 0 }
        ]
      }
    }
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "경매 비용"
  end

  test "renders bidder burden summary" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "user_simulation" => {} }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "낙찰자 부담 분석"
  end

  test "displays unit as manwon" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "user_simulation" => { "expected_bid" => nil, "distribution" => [] } }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "만원"
  end
end
