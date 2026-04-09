require "test_helper"

class InspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = properties(:safe_apartment)
    @risky_property = properties(:risky_villa)
    @user = users(:guest)
  end

  test "creates InspectionResult for each InspectionItem" do
    results = InspectionRunner.call(property: @safe_property, user: @user)
    assert_equal InspectionItem.count, results.size
  end

  test "detects non_extinguished_rights risk on risky_villa" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-002")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk, "risky_villa sale_detail has non_extinguished_rights, should detect risk"
  end

  test "detects lien from risky_villa remarks" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-020")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk, "risky_villa remarks contain 유치권, should detect lien risk"
  end

  test "detects lien/superficies pattern from risky_villa" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-011")
    return unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert_not_nil result
    assert result.auto?
    assert result.has_risk, "risky_villa has 유치권 in remarks/sale_detail"
  end

  test "safe apartment has no risks for structured rules" do
    InspectionRunner.call(property: @safe_property, user: @user)
    # rights-002: safe_apartment has empty non_extinguished_rights
    item = InspectionItem.find_by(code: "rights-002")
    if item
      result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
      assert_not_nil result
      assert_equal false, result.has_risk,
        "safe_apartment sale_detail has empty non_extinguished_rights, should not detect risk"
    end

    # rights-011: safe_apartment has no 유치권/법정지상권
    item = InspectionItem.find_by(code: "rights-011")
    if item
      result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
      assert_not_nil result
      assert_equal false, result.has_risk
    end
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
