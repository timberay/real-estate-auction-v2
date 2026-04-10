require "test_helper"

class PropertyInspectionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    @user = users(:guest)
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "full inspection flow: start → tab edit → grade" do
    # Start inspection
    post property_inspections_start_url(@property)
    assert_redirected_to edit_property_inspections_tab_url(@property, tab_key: "rights_analysis")

    # Verify items created
    assert_equal InspectionItem.count, InspectionResult.where(property: @property, user: @user).count

    # Visit each tab
    %w[ rights_analysis property_analysis profit_analysis field_check bidding ].each do |tab|
      get edit_property_inspections_tab_url(@property, tab_key: tab)
      assert_response :success
    end

    # View grade
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "override auto result preserves auto_value and shows as manual" do
    # Force rule-based fallback by disabling both mock and real LLM
    ENV.delete("USE_MOCK")
    saved_provider = ENV.delete("LLM_PROVIDER")
    saved_key = ENV.delete("GEMINI_API_KEY")

    PropertyInspectionService.call(property: @property, user: @user)

    auto_result = @property.inspection_results
      .where(user: @user, source_type: "auto")
      .first

    assert_not_nil auto_result, "Expected at least one auto result"
    original_risk = auto_result.has_risk
    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: (!original_risk).to_s
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal !original_risk, auto_result.has_risk
    assert_equal original_risk.to_s, auto_result.auto_value

    # Verify it appears correctly on the tab page
    get edit_property_inspections_tab_url(@property, tab_key: tab_key)
    assert_response :success
    assert_select "span", text: "수정됨"
  ensure
    ENV["LLM_PROVIDER"] = saved_provider if saved_provider
    ENV["GEMINI_API_KEY"] = saved_key if saved_key
  end

  test "inspection flow stores evidence for auto-detected results" do
    # Force rule-based fallback
    ENV.delete("USE_MOCK")
    saved_provider = ENV.delete("LLM_PROVIDER")
    saved_key = ENV.delete("GEMINI_API_KEY")

    post property_inspections_start_url(@property)

    auto_results = @property.inspection_results
      .where(user: @user, source_type: "auto")
      .where.not(evidence: nil)

    assert auto_results.any?, "At least one auto result should have evidence"

    auto_results.each do |result|
      assert_not_nil result.evidence["source_label"],
        "evidence for #{result.inspection_item.code} should have source_label"
      has_fields = result.evidence["fields"].present?
      has_keywords = result.evidence["keywords"].present?
      assert has_fields || has_keywords,
        "evidence for #{result.inspection_item.code} should have fields or keywords"
    end
  ensure
    ENV["LLM_PROVIDER"] = saved_provider if saved_provider
    ENV["GEMINI_API_KEY"] = saved_key if saved_key
  end

  test "manual input updates result" do
    PropertyInspectionService.call(property: @property, user: @user)

    manual_result = @property.inspection_results
      .joins(:inspection_item)
      .where(user: @user, source_type: nil)
      .first

    if manual_result
      tab_key = manual_result.inspection_item.tab
      patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
        resolutions: { manual_result.id => { has_risk: "true", resolvable: "true", resolution_note: "확인 완료" } }
      }
      manual_result.reload
      assert_equal true, manual_result.has_risk
      assert_equal true, manual_result.resolvable
      assert_equal "확인 완료", manual_result.resolution_note
    end
  end
end
