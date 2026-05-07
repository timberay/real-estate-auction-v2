require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    UserProperty.find_or_create_by!(user: @user, property: @property)
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
      .where(user: @user, source_type: "auto")
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
      .where(user: @user, source_type: "auto", has_risk: false)
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
      .where(user: @user)
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

  test "edit renders dependent items hidden when parent has_risk is false" do
    # rights-003 has_risk=false → rights-024 should be hidden
    # rights-024 depends_on rights-003 show_when_risk=true
    get edit_property_inspections_tab_url(@property, tab_key: "rights_analysis")
    assert_response :success
    assert_select "[data-depends-on-code='rights-003']" do |elements|
      elements.each { |el| assert_match(/hidden/, el["class"].to_s) }
    end
  end

  test "edit renders dependent items visible when parent has_risk matches show_when_risk" do
    risky = properties(:risky_villa)
    UserProperty.find_or_create_by!(user: @user, property: risky)
    # risky_villa: rights-003 has_risk=true → rights-024 visible
    get edit_property_inspections_tab_url(risky, tab_key: "rights_analysis")
    assert_response :success
    assert_select "[data-depends-on-code='rights-003']" do |elements|
      elements.each { |el| refute_match(/hidden/, el["class"].to_s) }
    end
  end

  test "unselected manual item preserves nil has_risk when saved" do
    result = inspection_results(:manual_unanswered)
    assert_nil result.has_risk, "precondition: has_risk should be nil"

    tab_key = result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        result.id => {
          resolution_note: ""
        }
      }
    }

    result.reload
    assert_nil result.has_risk, "has_risk should remain nil when user did not select any radio"
  end

  test "unselected auto resolvable preserves nil when saved" do
    auto_result = inspection_results(:risky_villa_rights_003)
    auto_result.update_columns(resolvable: nil)
    assert auto_result.auto?, "precondition: source_type should be auto"
    assert auto_result.has_risk, "precondition: has_risk should be true"
    assert_nil auto_result.resolvable, "precondition: resolvable should be nil"

    risky = properties(:risky_villa)
    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(risky, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          resolution_note: ""
        }
      }
    }

    auto_result.reload
    assert_nil auto_result.resolvable, "resolvable should remain nil when user did not select any radio"
  end

  test "AI source with risk persists resolvable and resolution_note from form" do
    ai_result = inspection_results(:risky_villa_rights_003)
    ai_result.update!(source_type: :ai, has_risk: true, resolvable: nil, resolution_note: nil)

    risky = properties(:risky_villa)
    UserProperty.find_or_create_by!(user: @user, property: risky)
    tab_key = ai_result.inspection_item.tab

    patch property_inspections_tab_url(risky, tab_key: tab_key), params: {
      resolutions: {
        ai_result.id => {
          resolvable: "true",
          resolution_note: "보증금 인수 가능"
        }
      }
    }

    ai_result.reload
    assert_equal true, ai_result.resolvable, "resolvable should persist for AI source"
    assert_equal "보증금 인수 가능", ai_result.resolution_note
    assert_equal "ai", ai_result.source_type, "source_type should remain ai"
  end

  test "update with no resolutions still sets flash" do
    patch property_inspections_tab_url(@property, tab_key: "rights_analysis"), params: {}

    assert_response :redirect
    tab_rating_flash = flash[:tab_rating]
    assert_not_nil tab_rating_flash
  end
end
