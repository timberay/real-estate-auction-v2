require "test_helper"

class PropertyAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "creates check results for property" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    property.property_check_results.destroy_all

    assert_difference "PropertyCheckResult.count", ChecklistItem.count do
      PropertyAnalysisService.call(property: property, user: @user)
    end
  end

  test "returns array of check results" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    results = PropertyAnalysisService.call(property: property, user: @user)

    assert_kind_of Array, results
    assert results.all? { |r| r.is_a?(PropertyCheckResult) }
  end
end
