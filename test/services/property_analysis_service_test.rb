require "test_helper"

class PropertyAnalysisServiceTest < ActiveSupport::TestCase
  test "creates check results for property" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    property.property_check_results.destroy_all

    assert_difference "PropertyCheckResult.count", ChecklistItem.count do
      PropertyAnalysisService.call(property: property)
    end
  end

  test "returns hash with results and pending_manual_items" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    result = PropertyAnalysisService.call(property: property)

    assert result.key?(:results)
    assert result.key?(:pending_manual_items)
  end
end
