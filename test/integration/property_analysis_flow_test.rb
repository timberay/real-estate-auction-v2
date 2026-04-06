# test/integration/property_analysis_flow_test.rb
require "test_helper"

class PropertyAnalysisFlowTest < ActionDispatch::IntegrationTest
  test "full analysis flow: show → analyze → checklist → rating" do
    get start_onboarding_url
    current_user = User.find_by(email: "guest@auction.local")

    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    current_user.user_properties.find_or_create_by!(property: property)

    # Pre-analysis: show page renders without redirect
    get property_url(property)
    assert_response :success

    # Start analysis → redirects to checklist
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_checklist_url(property)
    follow_redirect!
    assert_response :success

    # Build unified resolutions params
    resolutions = {}

    property.property_check_results.where(source_type: "auto", has_risk: true, user: current_user).each do |r|
      resolutions[r.id] = { resolvable: "false", resolution_note: "해결 불가" }
    end

    property.property_check_results.where(source_type: nil, user: current_user).each do |r|
      resolutions[r.id] = { has_risk: "false" }
    end

    patch property_analyses_checklist_url(property), params: { resolutions: resolutions }
    assert_redirected_to property_analyses_rating_url(property)
    follow_redirect!
    assert_response :success

    # Verify rating was set
    user_property = current_user.user_properties.find_by(property: property)
    assert user_property&.safety_rating.present?

    # Re-entry: show page redirects to rating
    get property_url(property)
    assert_redirected_to property_analyses_rating_path(property)
  end
end
