require "test_helper"

class Analyses::RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
    @current_user = User.find_by(email: "guest@auction.local")
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @current_user.user_properties.find_or_create_by!(property: @property)
    PropertyAnalysisService.call(property: @property, user: @current_user)
    @property.property_check_results.where(source_type: nil, user: @current_user).update_all(source_type: 1, has_risk: false)
  end

  test "GET show calculates rating and displays result" do
    get property_analyses_rating_url(@property)
    assert_response :success
    user_property = @current_user.user_properties.find_by(property: @property)
    assert user_property.safety_rating.present?
  end
end
