require "test_helper"

class Analyses::RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    PropertyAnalysisService.call(property: @property)
    @property.property_check_results.where(source_type: nil).update_all(source_type: 1, has_risk: false)
  end

  test "GET show calculates rating and displays result" do
    get property_analyses_rating_url(@property)
    assert_response :success
    assert_equal "safe", @property.reload.safety_rating
  end
end
