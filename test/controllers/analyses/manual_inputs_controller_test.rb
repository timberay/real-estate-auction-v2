require "test_helper"

class Analyses::ManualInputsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    PropertyAnalysisService.call(property: @property)
  end

  test "GET edit shows pending manual items" do
    get edit_property_analyses_manual_input_url(@property)
    assert_response :success
  end

  test "PATCH update redirects to results" do
    pending = @property.property_check_results.where(source_type: nil)
    if pending.any?
      answers = pending.pluck(:id).index_with { |_id| { has_risk: "false", manual_value: "no" } }
      patch property_analyses_manual_input_url(@property), params: { check_results: answers }
    else
      patch property_analyses_manual_input_url(@property), params: { check_results: {} }
    end
    assert_redirected_to edit_property_analyses_result_url(@property)
  end
end
