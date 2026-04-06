require "test_helper"

class Analyses::ResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
    @current_user = User.find_by(email: "guest@auction.local")
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    @current_user.user_properties.find_or_create_by!(property: @property)
    PropertyAnalysisService.call(property: @property, user: @current_user)
    @property.property_check_results.where(source_type: nil, user: @current_user).update_all(source_type: 1, has_risk: false)
  end

  test "GET edit shows all check results" do
    get edit_property_analyses_result_url(@property)
    assert_response :success
  end

  test "PATCH update saves resolvable and redirects to rating" do
    risk_results = @property.property_check_results.where(has_risk: true, user: @current_user)
    if risk_results.any?
      resolutions = risk_results.pluck(:id).index_with { |_| { resolvable: "false", resolution_note: "해결 불가" } }
      patch property_analyses_result_url(@property), params: { resolutions: resolutions }
    else
      patch property_analyses_result_url(@property), params: { resolutions: {} }
    end
    assert_redirected_to property_analyses_rating_url(@property)
  end
end
