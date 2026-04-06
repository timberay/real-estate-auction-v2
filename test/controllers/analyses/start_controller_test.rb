require "test_helper"

class Analyses::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
  end

  test "POST create runs analysis and redirects" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    current_user = User.find_by(email: "guest@auction.local")
    current_user.user_properties.find_or_create_by!(property: property)
    post property_analyses_start_url(property)
    assert_response :redirect
  end
end
