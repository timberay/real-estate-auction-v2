require "test_helper"

class Analyses::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
  end

  test "POST create runs analysis and always redirects to results" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    current_user = User.find_by(email: "guest@auction.local")
    current_user.user_properties.find_or_create_by!(property: property)
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_checklist_url(property)
  end
end
