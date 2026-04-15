require "test_helper"

class Inspections::GradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
  end

  test "show renders grade page" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "show assigns budget_setting" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "show filters results_by_tab with visible_for?" do
    # rights_009 depends on rights_003 with show_when_risk: true
    # rights_003 has_risk: false in fixture → rights_009 should be hidden
    item_009 = inspection_items(:rights_009)
    item_009.update!(depends_on: { "code" => "rights-003", "show_when_risk" => true })

    InspectionResult.create!(
      property: @property,
      inspection_item: item_009,
      user: users(:guest),
      source_type: :ai,
      has_risk: true
    )

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
        safe_count = cells[1].text.strip.to_i
        risk_count = cells[2].text.strip.to_i
        unanswered_count = cells[3].text.strip.to_i
        total = safe_count + risk_count + unanswered_count

        # rights_009 (risk=true) should be filtered out
        # Only rights_002 (safe), rights_003 (safe), manual_001 (unanswered) should remain
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
end
