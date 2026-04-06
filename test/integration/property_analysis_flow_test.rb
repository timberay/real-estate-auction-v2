require "test_helper"

class PropertyAnalysisFlowTest < ActionDispatch::IntegrationTest
  test "full analysis flow: list → analyze → manual input → results → rating" do
    get start_onboarding_url  # creates guest session
    current_user = User.find_by(email: "guest@auction.local")

    # Seed a property and add to user list
    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    current_user.user_properties.find_or_create_by!(property: property)

    # Visit list
    get properties_url
    assert_response :success

    # Visit property detail
    get property_url(property)
    assert_response :success

    # Start analysis
    post property_analyses_start_url(property)
    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Fill manual inputs (if any)
    pending = property.property_check_results.where(source_type: nil, user: current_user)
    if pending.any?
      answers = pending.pluck(:id).index_with { |_| { has_risk: "false", manual_value: "no" } }
      patch property_analyses_manual_input_url(property), params: { check_results: answers }
      assert_response :redirect
      follow_redirect!
    end

    # Fill resolutions
    risk_results = property.property_check_results.where(has_risk: true, user: current_user)
    if risk_results.any?
      resolutions = risk_results.pluck(:id).index_with { |_| { resolvable: "false", resolution_note: "해결 불가" } }
      patch property_analyses_result_url(property), params: { resolutions: resolutions }
      assert_response :redirect
      follow_redirect!
    end

    # Verify rating
    get property_analyses_rating_url(property)
    assert_response :success
    user_property = current_user.user_properties.find_by(property: property)
    assert user_property&.safety_rating.present?
  end
end
