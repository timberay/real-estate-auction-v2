require "test_helper"

class Inspections::GradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "show renders grade page" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "footer exposes a '전문가 상담' CTA alongside the PDF download (C14)" do
    get property_inspections_grade_url(@property)
    assert_response :success

    # C14: the PDF button shouldn't be the sole prominent action. Offer a
    # path to deeper help so users don't walk away with a PDF and no
    # answer to "should I bid?".
    assert_select "a", text: /전문가 상담/
  end

  test "show assigns budget_setting" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "show filters results_by_tab with visible_for?" do
    # rights_009 depends on rights_003 with show_when_risk: true (set in fixture)
    # rights_003 has_risk: false in fixture → rights_009 should be hidden
    result_009 = inspection_results(:safe_apartment_rights_009)
    result_009.update!(source_type: :ai, has_risk: true)

    get property_inspections_grade_url(@property)
    assert_response :success

    # rights_009 should NOT appear in the tab summary table
    # because rights-003 is safe (has_risk: false) and rights_009
    # only shows when risk (show_when_risk: true)
    assert_select "table" do
      assert_select "tr" do |rows|
        rights_row = rows.find { |r| r.css("a").any? { |a| a.text.include?("권리분석") } }
        next unless rights_row
        cells = rights_row.css("td")
        risk_count = cells[2].text.strip.to_i

        # rights_009 (risk=true) should be filtered out
        assert_equal 0, risk_count,
          "Expected 0 risk items in rights_analysis (rights_009 should be hidden), got #{risk_count}"
      end
    end
  end

  test "show responds to PDF format" do
    get property_inspections_grade_url(@property, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.content_type
  end

  test "show responds to CSV format with correct content type" do
    get property_inspections_grade_url(@property, format: :csv)
    assert_response :success
    assert_match %r{text/csv}, response.content_type
  end

  test "CSV response has attachment disposition with correct filename" do
    travel_to Time.zone.parse("2026-05-10 12:00:00") do
      get property_inspections_grade_url(@property, format: :csv)
    end
    assert_response :success
    disposition = response.headers["Content-Disposition"]
    assert_match "attachment", disposition
    assert_match "2026-05-10.csv", disposition
    assert_match @property.case_number, URI.decode_www_form_component(disposition)
  end

  test "CSV response body starts with UTF-8 BOM" do
    get property_inspections_grade_url(@property, format: :csv)
    assert_response :success
    assert response.body.start_with?("\xEF\xBB\xBF"), "Expected UTF-8 BOM at start of CSV body"
  end
end
