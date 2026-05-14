require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders verdict summary text" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "말소기준권리"
  end

  test "does not duplicate the overall verdict (no emoji, label, or 체크리스트 분석 결과 text)" do
    # The overall verdict already lives on the inspection tab bar / bid opinion box.
    # Repeating it here as 🔴 위험 conflicted with the overall 주의 verdict and confused users.
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_no_text "체크리스트 분석 결과"
    assert_no_text "🔴"
    assert_no_text "🟡"
    assert_no_text "🟢"
  end

  test "renders appraisal price and min bid price" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "감정가"
    assert_text "최저매각가"
  end

  test "renders checklist review summary" do
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "체크리스트 검토"
  end

  test "renders opportunity badge when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.opportunity_type = "hug_waiver"
    report.opportunity_reason = "HUG가 대항력을 포기"
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "안전 기회 물건"
  end

  test "renders assumed amount" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "인수 금액"
  end

  test "formats prices correctly from won to Korean currency" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    # Fixture: appraisal_price=800000000, min_bid_price=560000000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "8억"
    assert_text "5억 6,000만원"
  end

  test "formats assumed and total risk amounts in 만원, not raw 원" do
    # risky_villa_report.assumed_amount = 30_000_000 → 3,000만원
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "3,000만원"
    assert_no_text "30,000,000원"
  end

  test "renders [code] question for each checklist reference" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({ "checklist_references" => [ "rights-002" ] })
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    expected_question = InspectionItem.find_by!(code: "rights-002").question
    assert_text "[rights-002]"
    assert_text expected_question
  end

  test "renders (삭제된 항목) fallback for missing codes" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({ "checklist_references" => [ "tax-007" ] })
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "[tax-007]"
    assert_text "(삭제된 항목)"
  end

  test "renders 위험 항목 없음 when refs are empty" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = JSON.generate({ "checklist_references" => [] })
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "위험 항목 없음"
  end

  test "renders unevaluated_rights warning banner when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "unevaluated_rights" => [
          { "type" => "유치권", "amount" => 50_000_000 }
        ],
        "disclaimer" => "추정치이며, 별도 평가 필요 항목이 1건 있습니다. 베테랑/공인중개사 검토를 권장합니다."
      }
    })
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "자동 계산 불가 권리"
    assert_text "유치권"
    assert_text "별도 평가 필요"
  end

  test "does not render unevaluated_rights banner when all rights are summable" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "unevaluated_rights" => [],
        "disclaimer" => nil
      }
    })
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_no_text "자동 계산 불가 권리"
  end

  test "renders distribution simulator when tenants are present" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "tenants" => [
          {
            "name" => "김임차", "deposit" => 50_000_000, "opposing_power" => true,
            "has_priority_repayment" => true, "effective_date" => "2023-06-15", "priority_rank" => 1
          }
        ],
        "unevaluated_rights" => [],
        "disclaimer" => nil
      }
    })
    property = properties(:risky_villa)
    property.min_bid_price = 100_000_000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "예상 매각가 기준 임차인 미배당 잔액"
    assert_text "김임차"
    assert_text "대항력 임차인 인수 부담 합계"
    assert_text "최우선변제"
    assert_text "집행비용"
  end

  test "simulator table headers have scope=col for screen readers" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "tenants" => [
          {
            "name" => "김임차", "deposit" => 50_000_000, "opposing_power" => true,
            "has_priority_repayment" => true, "effective_date" => "2023-06-15", "priority_rank" => 1
          }
        ],
        "unevaluated_rights" => [],
        "disclaimer" => nil
      }
    })
    property = properties(:risky_villa)
    property.min_bid_price = 100_000_000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_selector "th[scope='col']", count: 4
  end

  test "does NOT render simulator section when there are no tenants" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_no_text "예상 매각가 기준 임차인 미배당 잔액"
  end

  test "renders first-priority dividend row when small tenant is eligible (T1.3 / W1-4 / C25)" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "tenants" => [
          {
            "name" => "김임차", "deposit" => 50_000_000,
            "move_in_date" => "2024-01-01", "confirmed_date" => "2024-01-02",
            "dividend_requested" => true, "opposing_power" => true,
            "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
          }
        ],
        "unevaluated_rights" => [],
        "disclaimer" => nil
      }
    })
    property = properties(:risky_villa)
    property.min_bid_price = 200_000_000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    # 경기도 수원시 → overcrowded tier, 현행 보호 4800만. 50M ≤ 145M 한도 → 4800만 first-priority.
    assert_text "최우선변제 김임차"
    assert_text "4,800만원"
    # 베테랑 검증용 시점/지역 캡션
    assert_selector "[data-testid='small-tenant-period']", text: /과밀억제권역/
    assert_selector "[data-testid='small-tenant-period']", text: /2023-02-21/
  end

  test "does NOT render first-priority row when tenant deposit exceeds 한도" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({
      "calculated" => {
        "tenants" => [
          {
            "name" => "고액임차", "deposit" => 500_000_000,
            "move_in_date" => "2024-01-01", "confirmed_date" => "2024-01-02",
            "dividend_requested" => true, "opposing_power" => true,
            "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
          }
        ],
        "unevaluated_rights" => [],
        "disclaimer" => nil
      }
    })
    property = properties(:risky_villa)
    property.min_bid_price = 600_000_000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    # 보증금 5억 > 한도 1.45억 → first-priority 0 → amber list 자체가 렌더되지 않음
    assert_no_text "최우선변제 고액임차"
  end

  test "checklist_refs memoizes — single query per render even with multiple calls" do
    report = rights_analysis_reports(:risky_villa_report)
    report.report_data = JSON.generate({ "checklist_references" => [ "rights-002", "rights-003" ] })
    property = properties(:risky_villa)

    queries = []
    callback = ->(_, _, _, _, payload) {
      sql = payload[:sql]
      queries << sql if sql =~ /\bFROM\s+"?inspection_items"?\b/i && sql !~ /sqlite_master|PRAGMA/i
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      render_inline(ReportSummaryComponent.new(report: report, property: property))
    end

    assert_equal 1, queries.size, "expected exactly one inspection_items SELECT per render, got: #{queries.size}"
  end
end
