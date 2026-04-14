require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
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

  test "update sets flash with tab rating and unanswered count" do
    result = @property.inspection_results
      .where(user: users(:guest))
      .joins(:inspection_item)
      .where(inspection_items: { tab: InspectionItem.tabs["rights_analysis"] })
      .first

    patch property_inspections_tab_url(@property, tab_key: "rights_analysis"), params: {
      resolutions: {
        result.id => {
          has_risk: "false"
        }
      }
    }

    assert_response :redirect
    tab_rating_flash = flash[:tab_rating]
    assert_not_nil tab_rating_flash
    assert_includes %w[safe caution danger incomplete], tab_rating_flash["rating"]
    assert_equal "권리분석", tab_rating_flash["label"]
    assert tab_rating_flash.key?("unanswered_count")
  end

  test "update with no resolutions still sets flash" do
    patch property_inspections_tab_url(@property, tab_key: "rights_analysis"), params: {}

    assert_response :redirect
    tab_rating_flash = flash[:tab_rating]
    assert_not_nil tab_rating_flash
  end
end
