require "test_helper"

class Analyses::StartControllerTest < ActionDispatch::IntegrationTest
  test "POST create runs analysis and redirects" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    post property_analyses_start_url(property)
    assert_response :redirect
  end
end
