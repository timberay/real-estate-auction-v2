require "test_helper"

class AutoCheckRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002")
  end

  test "creates PropertyCheckResult for each ChecklistItem" do
    results = AutoCheckRunner.call(property: @safe_property)
    assert_equal ChecklistItem.count, results.size
  end

  test "detects 유치권/법정지상권 in remarks (rights-011)" do
    AutoCheckRunner.call(property: @risky_property)
    result = @risky_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "rights-011" })
    assert result.auto?
    assert result.has_risk
  end

  test "no risk for safe property remarks (rights-011)" do
    AutoCheckRunner.call(property: @safe_property)
    result = @safe_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "rights-011" })
    assert result.auto?
    assert_not result.has_risk
  end

  test "detects 위반건축물 from building ledger (property-004)" do
    AutoCheckRunner.call(property: @risky_property)
    result = @risky_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "property-004" })
    assert result.has_risk
  end
end
