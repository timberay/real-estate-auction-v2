require "test_helper"

class InspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001").property
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002").property
    @user = users(:guest)
  end

  test "creates InspectionResult for each InspectionItem" do
    results = InspectionRunner.call(property: @safe_property, user: @user)
    assert_equal InspectionItem.count, results.size
  end

  test "auto-detects risks from raw_data when detection rule exists" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-011")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk
  end

  test "leaves items without detection rules as unanswered" do
    InspectionRunner.call(property: @safe_property, user: @user)
    item = InspectionItem.find_by(code: "manual-001")
    return unless item
    result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert_nil result.source_type
    assert_nil result.has_risk
  end

  test "is idempotent — running twice does not create duplicates" do
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_first = InspectionResult.where(property: @safe_property, user: @user).count
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_second = InspectionResult.where(property: @safe_property, user: @user).count
    assert_equal count_after_first, count_after_second
  end

  test "does not overwrite manual answers on re-run" do
    InspectionRunner.call(property: @safe_property, user: @user)
    item = InspectionItem.find_by(code: "manual-001")
    return unless item
    result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
    result.update!(source_type: "manual", has_risk: true, resolvable: true)

    InspectionRunner.call(property: @safe_property, user: @user)
    result.reload
    assert result.manual?
    assert result.has_risk
  end
end
