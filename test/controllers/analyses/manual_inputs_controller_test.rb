require "test_helper"

class Analyses::ManualInputsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
    @current_user = User.find_by(email: "guest@auction.local")
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @current_user.user_properties.find_or_create_by!(property: @property)
    PropertyAnalysisService.call(property: @property, user: @current_user)
  end

  test "GET edit shows pending manual items" do
    get edit_property_analyses_manual_input_url(@property)
    assert_response :success
  end

  test "PATCH update redirects to results" do
    pending = @property.property_check_results.where(source_type: nil, user: @current_user)
    if pending.any?
      answers = pending.pluck(:id).index_with { |_id| { has_risk: "false", manual_value: "no" } }
      patch property_analyses_manual_input_url(@property), params: { check_results: answers }
    else
      patch property_analyses_manual_input_url(@property), params: { check_results: {} }
    end
    assert_redirected_to edit_property_analyses_result_url(@property)
  end
end
