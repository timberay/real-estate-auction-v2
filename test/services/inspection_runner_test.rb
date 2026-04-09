require "test_helper"

class InspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = properties(:safe_apartment)
    @risky_property = properties(:risky_villa)
    @officetel = properties(:unanalyzed_officetel)
    @basement_villa = properties(:basement_villa)
    @high_view_apartment = properties(:high_view_apartment)
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

  # === Auto grade: nil handling (spec principle) ===

  test "rights-002: nil sale_detail treated as safe (not nil)" do
    InspectionRunner.call(property: @officetel, user: @user)
    result = find_result(@officetel, "rights-002")
    return unless result
    assert_equal "auto", result.source_type, "should auto-detect even without sale_detail"
    assert_equal false, result.has_risk, "no sale_detail = no rights to assume = safe"
  end

  test "rights-011: blank text treated as safe (not nil)" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-011")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "rights-011: detects superficies_details field" do
    @safe_property.sale_detail.update!(superficies_details: "법정지상권 성립 가능")
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-011")
    return unless result
    assert_equal true, result.has_risk, "superficies_details with 법정지상권 should detect risk"
  end

  test "property-002: blank text treated as safe (not nil)" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "property-002")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "rights-020: blank text treated as safe (not nil)" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-020")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  # === Auto grade: new rules ===

  test "rights-019: apartment is always safe regardless of land_category" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-019")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk, "아파트 is always safe for 일체 매각"
  end

  test "rights-019: non-apartment with non-전유 land_category is risky" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "rights-019")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "빌라 with 대지 land_category = separate land risk"
  end

  test "property-006: apartment detected as safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "property-006")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "property-006: non-apartment detected as risk" do
    InspectionRunner.call(property: @risky_property, user: @user)
    result = find_result(@risky_property, "property-006")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk
  end

  test "resale-003: basement detected as risk" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "resale-003")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "지하1층 should be detected as basement"
  end

  test "resale-003: above-ground is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "resale-003")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "property-001: share_description present means partial share risk" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "property-001")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "1/2 지분 share_description = partial share"
  end

  test "property-001: empty share_description is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "property-001")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "tax-006: exclusive_area under 85 is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "tax-006")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk, "84.5㎡ < 85 = VAT exempt"
  end

  test "tax-006: exclusive_area 85 or above is risk" do
    InspectionRunner.call(property: @high_view_apartment, user: @user)
    result = find_result(@high_view_apartment, "tax-006")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "120㎡ >= 85 = VAT applies"
  end

  test "market-012: view_count under 500 is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "market-012")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk, "view_count=5 < 500 = low competition"
  end

  test "market-012: view_count 500+ is risk" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "market-012")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "view_count=800 >= 500 = high competition"
  end

  # === Partial grade rules ===

  test "rights-005: detects 무허가 in specification_remarks" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "rights-005")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "무허가 증축 in specification_remarks should detect"
  end

  test "rights-005: no keywords returns nil" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-005")
    return unless result
    assert_nil result.has_risk, "no 무허가/미등기 keywords = cannot determine"
  end

  test "inspect-001: detects 균열 in appraisal_points" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "inspect-001")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk, "균열 in appraisal_points should detect"
  end

  test "inspect-001: no keywords returns nil" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "inspect-001")
    return unless result
    assert_nil result.has_risk
  end

  test "inspect-004: non-officetel is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "inspect-004")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "inspect-004: officetel returns nil (needs manual confirm)" do
    InspectionRunner.call(property: @officetel, user: @user)
    result = find_result(@officetel, "inspect-004")
    return unless result
    assert_nil result.has_risk, "오피스텔 needs 구청 confirmation"
  end

  test "market-006: apartment with building_name is safe" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "market-006")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk
  end

  test "market-006: non-apartment returns nil" do
    InspectionRunner.call(property: @risky_property, user: @user)
    result = find_result(@risky_property, "market-006")
    return unless result
    assert_nil result.has_risk, "빌라 cannot auto-determine 단지형"
  end

  test "rights-021: detects 전세사기 keyword in remarks" do
    InspectionRunner.call(property: @basement_villa, user: @user)
    result = find_result(@basement_villa, "rights-021")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal true, result.has_risk
  end

  test "rights-021: no keywords returns nil" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "rights-021")
    return unless result
    assert_nil result.has_risk
  end

  test "bidding-001: 진행중 status provides info (auto)" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "bidding-001")
    return unless result
    assert_equal "auto", result.source_type
    assert_equal false, result.has_risk, "진행중 = confirmed active"
  end

  test "bidding-003: calculates deposit amount (auto)" do
    InspectionRunner.call(property: @safe_property, user: @user)
    result = find_result(@safe_property, "bidding-003")
    return unless result
    assert_equal "auto", result.source_type
    # min_bid_price is 560000000, 10% = 56000000
    assert_not_nil result.has_risk
  end

  # === Removed rules: registry/building_ledger should not auto-detect ===

  test "registry transcript items are not auto-detected" do
    InspectionRunner.call(property: @safe_property, user: @user)
    %w[rights-001 rights-007 rights-008].each do |code|
      result = find_result(@safe_property, code)
      next unless result
      assert_nil result.source_type, "#{code} should not be auto-detected (registry_transcript scope)"
    end
  end

  test "building ledger items are not auto-detected" do
    InspectionRunner.call(property: @safe_property, user: @user)
    %w[property-004 property-005 resale-002].each do |code|
      result = find_result(@safe_property, code)
      next unless result
      assert_nil result.source_type, "#{code} should not be auto-detected (building_ledger scope)"
    end
  end

  private

  def find_result(property, code)
    item = InspectionItem.find_by(code: code)
    return nil unless item
    InspectionResult.find_by(property: property, inspection_item: item, user: @user)
  end
end
