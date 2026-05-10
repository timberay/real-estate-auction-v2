require "test_helper"
require "csv"

class Export::InspectionCsvExporterTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    @report = RightsAnalysisReport.find_by(property: @property, user: @user)
    @simulation = EvictionSimulation.find_by(property: @property)
  end

  # ---------------------------------------------------------------------------
  # BOM
  # ---------------------------------------------------------------------------
  test "output starts with UTF-8 BOM" do
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    assert csv.start_with?("\xEF\xBB\xBF"), "Expected UTF-8 BOM as first bytes"
  end

  # ---------------------------------------------------------------------------
  # Header row
  # ---------------------------------------------------------------------------
  test "first row contains Korean headers in correct order" do
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    headers = rows[0]

    expected = %w[사건번호 법원 소재지 감정가 최저가 유찰횟수 다음매각기일 종합판정 인수금액 임차인수 명도난이도 분석일시]
    assert_equal expected, headers
  end

  # ---------------------------------------------------------------------------
  # Happy-path data row (safe_apartment property; no eviction sim linked)
  # ---------------------------------------------------------------------------
  test "data row contains correct values for safe_apartment" do
    travel_to Time.zone.parse("2026-05-10 12:00:00") do
      InspectionResult.where(property: @property, user: @user).destroy_all
      UserProperty.find_or_create_by!(user: @user, property: @property)

      csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
      rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
      row = rows[1]

      assert_equal @property.case_number, row[0]
      assert_equal @property.court_name, row[1]
      assert_equal @property.address, row[2]
      assert_equal @property.appraisal_price.to_s, row[3]
      assert_equal @property.min_bid_price.to_s, row[4]
      assert_equal @property.failed_bid_count.to_s, row[5]
    end
  end

  # ---------------------------------------------------------------------------
  # Verdict label mapping — stub overall_rating to avoid coverage gate
  # ---------------------------------------------------------------------------
  test "maps :safe verdict to 안전" do
    assert_verdict_label(:safe, "안전")
  end

  test "maps :caution verdict to 주의" do
    assert_verdict_label(:caution, "주의")
  end

  test "maps :danger verdict to 위험" do
    assert_verdict_label(:danger, "위험")
  end

  test "maps :incomplete verdict to 미완료" do
    assert_verdict_label(:incomplete, "미완료")
  end

  # ---------------------------------------------------------------------------
  # Missing rights_analysis_report → blanks
  # ---------------------------------------------------------------------------
  test "인수금액 is blank when no report exists" do
    RightsAnalysisReport.where(property: @property, user: @user).delete_all
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_nil rows[1][8], "Expected blank 인수금액 when no report"
  end

  test "임차인수 is 0 when no report exists" do
    RightsAnalysisReport.where(property: @property, user: @user).delete_all
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_equal "0", rows[1][9]
  end

  test "분석일시 is blank when no report exists" do
    RightsAnalysisReport.where(property: @property, user: @user).delete_all
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_nil rows[1][11], "Expected blank 분석일시 when no report"
  end

  test "분석일시 is formatted as YYYY-MM-DD HH:MM when report exists" do
    travel_to Time.zone.parse("2026-05-10 12:34:56") do
      report = RightsAnalysisReport.create!(
        property: @property,
        user: @user,
        base_right_type: "근저당",
        base_right_date: "2024-01-15",
        base_right_holder: "은행",
        assumed_amount: 0,
        total_risk_amount: 0,
        verdict: 0,
        analyzed_at: Time.current
      )
      csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
      rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
      assert_match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, rows[1][11], "분석일시 should be formatted as YYYY-MM-DD HH:MM")
    ensure
      report&.destroy
    end
  end

  # ---------------------------------------------------------------------------
  # Missing eviction_simulation → blank difficulty
  # ---------------------------------------------------------------------------
  test "명도난이도 is blank when no simulation linked to property" do
    EvictionSimulation.where(property: @property).delete_all
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_nil rows[1][10], "Expected blank 명도난이도 when no simulation"
  end

  test "명도난이도 is blank when simulation exists but difficulty_level is nil" do
    sim = EvictionSimulation.create!(property: @property, difficulty_level: nil, completed: false)
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_nil rows[1][10], "Expected blank 명도난이도 when difficulty_level is nil"
  ensure
    sim&.destroy
  end

  # ---------------------------------------------------------------------------
  # Eviction difficulty label mapping
  # ---------------------------------------------------------------------------
  test "maps difficulty_level 'high' to 높음" do
    sim = EvictionSimulation.create!(property: @property, difficulty_level: "high", completed: false)
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_equal "높음", rows[1][10]
  ensure
    sim&.destroy
  end

  test "maps difficulty_level 'medium' to 중간" do
    sim = EvictionSimulation.create!(property: @property, difficulty_level: "medium", completed: false)
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_equal "중간", rows[1][10]
  ensure
    sim&.destroy
  end

  test "maps difficulty_level 'low' to 낮음" do
    sim = EvictionSimulation.create!(property: @property, difficulty_level: "low", completed: false)
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_equal "낮음", rows[1][10]
  ensure
    sim&.destroy
  end

  private

  def assert_verdict_label(verdict, expected_label)
    csv = Export::InspectionCsvExporter.new(property: @property, user: @user, verdict: verdict).to_csv
    rows = CSV.parse(csv.delete_prefix("\xEF\xBB\xBF"))
    assert_equal expected_label, rows[1][7]
  end
end
