require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    # Force rule-based fallback so auto results are created
    @saved_mock = ENV.delete("USE_MOCK")
    @saved_provider = ENV.delete("LLM_PROVIDER")
    @saved_key = ENV.delete("GEMINI_API_KEY")
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  teardown do
    ENV["USE_MOCK"] = @saved_mock if @saved_mock
    ENV["LLM_PROVIDER"] = @saved_provider if @saved_provider
    ENV["GEMINI_API_KEY"] = @saved_key if @saved_key
  end

  test "edit renders tab items" do
    get edit_property_inspections_tab_url(@property, tab_key: "rights_analysis")
    assert_response :success
  end

  test "edit returns 404 for invalid tab" do
    get edit_property_inspections_tab_url(@property, tab_key: "invalid")
    assert_response :not_found
  end

  test "override auto result changes source_type to manual and preserves auto_value" do
    auto_result = @property.inspection_results
      .where(user: users(:guest), source_type: "auto")
      .first

    original_has_risk = auto_result.has_risk
    new_has_risk = !original_has_risk
    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: new_has_risk.to_s
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal new_has_risk, auto_result.has_risk
    assert_equal original_has_risk.to_s, auto_result.auto_value
  end

  test "override auto result with risk includes resolvable and note" do
    auto_result = @property.inspection_results
      .where(user: users(:guest), source_type: "auto", has_risk: false)
      .first

    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: "true",
          resolvable: "true",
          resolution_note: "문서 재확인 결과 위험"
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal true, auto_result.has_risk
    assert_equal true, auto_result.resolvable
    assert_equal "문서 재확인 결과 위험", auto_result.resolution_note
    assert_equal "false", auto_result.auto_value
  end
end
