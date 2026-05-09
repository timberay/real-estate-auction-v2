require "test_helper"
require "ostruct"

class InspectionItemTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    item = InspectionItem.new(
      code: "test-001",
      tab: "rights_analysis",
      tab_position: 1,
      category: "권리분석",
      question: "테스트 질문입니까?",
      priority: "상"
    )
    assert item.valid?
  end

  test "code is required and unique" do
    InspectionItem.create!(code: "unique-001", tab: "rights_analysis", tab_position: 1, category: "권리분석", question: "Q?", priority: "상")
    dup = InspectionItem.new(code: "unique-001", tab: "rights_analysis", tab_position: 2, category: "권리분석", question: "Q2?", priority: "상")
    assert_not dup.valid?
  end

  test "tab enum values" do
    item = InspectionItem.new(code: "enum-test", tab: "rights_analysis", tab_position: 1, category: "C", question: "Q?", priority: "상")
    assert item.rights_analysis?

    item.tab = "profit_analysis"
    assert item.profit_analysis?

    item.tab = "field_check"
    assert item.field_check?

    item.tab = "bidding"
    assert item.bidding?
  end

  test "question and category are required" do
    item = InspectionItem.new(code: "test-002", tab: "rights_analysis", tab_position: 1, question: nil, category: nil, priority: "상")
    assert_not item.valid?
    assert_includes item.errors[:question], "can't be blank"
    assert_includes item.errors[:category], "can't be blank"
  end

  test "ordered scope returns items by tab and tab_position" do
    items = InspectionItem.ordered
    prev = nil
    items.each do |item|
      if prev && prev.tab == item.tab
        assert prev.tab_position <= item.tab_position
      end
      prev = item
    end
  end

  test "for_tab scope returns items for a specific tab" do
    sale_items = InspectionItem.for_tab(:rights_analysis)
    assert sale_items.all?(&:rights_analysis?)
  end

  test "yes_means_safe defaults to true" do
    item = InspectionItem.new(
      code: "default-test",
      tab: "rights_analysis",
      tab_position: 1,
      category: "권리분석",
      question: "기본값 테스트?",
      priority: "상"
    )
    assert_equal true, item.yes_means_safe
  end

  test "yes_means_safe can be set to false" do
    item = InspectionItem.new(
      code: "inverted-test",
      tab: "rights_analysis",
      tab_position: 1,
      category: "권리분석",
      question: "반전 테스트?",
      priority: "상",
      yes_means_safe: false
    )
    assert_equal false, item.yes_means_safe
  end

  test "applicable_for? returns true when applicable_types is nil (applies to all)" do
    item = InspectionItem.create!(
      code: "applicable-all",
      tab: "rights_analysis",
      tab_position: 1,
      category: "권리분석",
      question: "모든 타입에 적용?",
      priority: "상",
      applicable_types: nil
    )
    assert item.applicable_for?("단독주택")
    assert item.applicable_for?("아파트")
  end

  test "applicable_for? returns true when property_type is in applicable_types" do
    item = InspectionItem.create!(
      code: "applicable-specific",
      tab: "profit_analysis",
      tab_position: 1,
      category: "수익분석",
      question: "특정 타입에만 적용?",
      priority: "중",
      applicable_types: [ "아파트", "오피스텔" ]
    )
    assert item.applicable_for?("아파트")
    assert item.applicable_for?("오피스텔")
  end

  test "applicable_for? returns false when property_type is not in applicable_types" do
    item = InspectionItem.create!(
      code: "applicable-exclude",
      tab: "field_check",
      tab_position: 1,
      category: "현장확인",
      question: "특정 타입 제외?",
      priority: "하",
      applicable_types: [ "아파트" ]
    )
    refute item.applicable_for?("단독주택")
  end

  # skip_for? tests
  test "skip_for? returns false when depends_on is blank" do
    item = InspectionItem.new(code: "child-001", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    assert_equal false, item.skip_for?({})
  end

  test "skip_for? returns true when parent result does not exist" do
    item = InspectionItem.new(code: "child-002", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "rights-003", "show_when_risk" => true })
    assert_equal true, item.skip_for?({})
  end

  test "skip_for? returns true when parent has_risk is nil" do
    item = InspectionItem.new(code: "child-003", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "parent-001", "show_when_risk" => true })
    parent_result = OpenStruct.new(has_risk: nil)
    assert_equal true, item.skip_for?({ "parent-001" => parent_result })
  end

  test "skip_for? returns true when parent has_risk does not match show_when_risk" do
    item = InspectionItem.new(code: "child-004", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "parent-001", "show_when_risk" => true })
    parent_result = OpenStruct.new(has_risk: false)
    assert_equal true, item.skip_for?({ "parent-001" => parent_result })
  end

  test "skip_for? returns false when parent has_risk matches show_when_risk" do
    item = InspectionItem.new(code: "child-005", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "parent-001", "show_when_risk" => true })
    parent_result = OpenStruct.new(has_risk: true)
    assert_equal false, item.skip_for?({ "parent-001" => parent_result })
  end

  # visible_for? tests
  test "visible_for? returns true when applicable and not skipped" do
    item = InspectionItem.new(code: "vis-001", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      applicable_types: nil, depends_on: nil)
    assert item.visible_for?(property_type: "아파트", answered_results: {})
  end

  test "visible_for? returns false when not applicable for property type" do
    item = InspectionItem.new(code: "vis-002", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      applicable_types: [ "상가" ], depends_on: nil)
    refute item.visible_for?(property_type: "아파트", answered_results: {})
  end

  test "visible_for? returns false when skipped by parent dependency" do
    item = InspectionItem.new(code: "vis-003", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      applicable_types: nil,
      depends_on: { "code" => "parent-001", "show_when_risk" => true })
    parent_result = OpenStruct.new(has_risk: false)
    refute item.visible_for?(property_type: "아파트", answered_results: { "parent-001" => parent_result })
  end

  # applicable_for_type scope tests
  test "applicable_for_type scope returns items with nil applicable_types" do
    item = InspectionItem.create!(code: "scope-all", tab: "rights_analysis", tab_position: 99,
      category: "권리분석", question: "모든 타입?", priority: "상", applicable_types: nil)
    assert_includes InspectionItem.applicable_for_type("아파트"), item
  end

  test "applicable_for_type scope returns items matching the property type" do
    item = InspectionItem.create!(code: "scope-match", tab: "rights_analysis", tab_position: 99,
      category: "권리분석", question: "아파트 전용?", priority: "상", applicable_types: [ "아파트", "오피스텔" ])
    assert_includes InspectionItem.applicable_for_type("아파트"), item
    assert_not_includes InspectionItem.applicable_for_type("상가"), item
  end

  test "applicable_for_type scope returns all when property_type is blank" do
    item = InspectionItem.create!(code: "scope-blank", tab: "rights_analysis", tab_position: 99,
      category: "권리분석", question: "제한된 타입?", priority: "상", applicable_types: [ "상가" ])
    assert_includes InspectionItem.applicable_for_type(nil), item
    assert_includes InspectionItem.applicable_for_type(""), item
  end

  # Multi-level skip_for? tests
  test "skip_for? cascades when parent is skipped (grandparent unanswered)" do
    grandparent = InspectionItem.new(code: "gp-001", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-001", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-001", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-001", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-001", "show_when_risk" => true })

    all_items = { "gp-001" => grandparent, "p-001" => parent, "c-001" => child }
    # grandparent unanswered → parent skipped → child skipped
    assert child.skip_for?({}, all_items_by_code: all_items)
  end

  test "skip_for? shows grandchild when full chain matches" do
    grandparent = InspectionItem.new(code: "gp-002", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-002", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-002", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-002", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-002", "show_when_risk" => true })

    gp_result = OpenStruct.new(has_risk: true)
    p_result = OpenStruct.new(has_risk: true)
    answered = { "gp-002" => gp_result, "p-002" => p_result }
    all_items = { "gp-002" => grandparent, "p-002" => parent, "c-002" => child }

    refute child.skip_for?(answered, all_items_by_code: all_items)
  end

  test "skip_for? skips grandchild when intermediate parent is safe" do
    grandparent = InspectionItem.new(code: "gp-003", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-003", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-003", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-003", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-003", "show_when_risk" => true })

    gp_result = OpenStruct.new(has_risk: true)
    p_result = OpenStruct.new(has_risk: false) # safe → child should be skipped
    answered = { "gp-003" => gp_result, "p-003" => p_result }
    all_items = { "gp-003" => grandparent, "p-003" => parent, "c-003" => child }

    assert child.skip_for?(answered, all_items_by_code: all_items)
  end

  test "skip_for? handles circular dependency without infinite loop" do
    item_a = InspectionItem.new(code: "circ-a", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "circ-b", "show_when_risk" => true })
    item_b = InspectionItem.new(code: "circ-b", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "circ-a", "show_when_risk" => true })

    all_items = { "circ-a" => item_a, "circ-b" => item_b }
    # Should not raise SystemStackError, should return true (skip)
    assert item_a.skip_for?({}, all_items_by_code: all_items)
  end
end

# 2026-05 reorganization assertions: verify the seed JSON, when loaded, yields
# the expected post-reorganization state. Uses a private DB scope so existing
# fixtures (which mirror a curated subset for other tests) are not disturbed.
class InspectionItemReorganization202605Test < ActiveSupport::TestCase
  include ChecklistSeedHelper

  setup do
    load_checklist_seed!
  end

  test "checklist count after reorganization is 44" do
    # A6 adds 5 veteran items (rights-025..029); B2 splits rights-008 into 당해세 + 일반국세 (rights-030); count is now 50
    assert_equal 50, InspectionItem.count
  end

  test "inspect-005 lives in field_check tab" do
    item = InspectionItem.find_by!(code: "inspect-005")
    assert_equal "field_check", item.tab
    assert_equal "현장조사&서류검증", item.category
  end

  test "manual-001 lives in rights_analysis tab" do
    item = InspectionItem.find_by!(code: "manual-001")
    assert_equal "rights_analysis", item.tab
    assert_equal "권리분석", item.category
  end

  test "eviction-001 category moved to 현장조사&서류검증" do
    item = InspectionItem.find_by!(code: "eviction-001")
    assert_equal "field_check", item.tab
    assert_equal "현장조사&서류검증", item.category
  end

  test "inspect-009 question text updated" do
    item = InspectionItem.find_by!(code: "inspect-009")
    assert_equal "현장 방문(임장)을 통해 부동산으로부터 매도 가능 정보를 얻었습니까?", item.question
  end

  test "tax-007 and exit-002 are deleted" do
    assert_nil InspectionItem.find_by(code: "tax-007")
    assert_nil InspectionItem.find_by(code: "exit-002")
  end

  # A6: rights-021 priority bump + 5 new veteran items
  test "rights-021 (전세사기 특별법 우선매수권) priority is 상" do
    item = InspectionItem.find_by!(code: "rights-021")
    assert_equal "상", item.priority
  end

  test "veteran-required items rights-025..029 all exist in seed" do
    %w[rights-025 rights-026 rights-027 rights-028 rights-029].each do |code|
      assert InspectionItem.exists?(code: code), "#{code} must exist in seeds"
    end
  end

  # B2 (E-6): split rights-008 (선순위 세금 압류) into 당해세 vs 일반국세
  test "rights-008 is now scoped to 당해세 (재산세·종합부동산세)" do
    item = InspectionItem.find_by!(code: "rights-008")
    assert_match(/당해세/, item.question, "rights-008 question must mention 당해세")
    assert_match(/재산세|종합부동산세/, item.question, "rights-008 question must mention 재산세 or 종합부동산세")
    assert_equal "상", item.priority
    assert_equal false, item.yes_means_safe
  end

  test "rights-030 covers 일반 국세 (당해세 외) as a separate checklist item" do
    item = InspectionItem.find_by!(code: "rights-030")
    assert_match(/일반 국세|일반국세/, item.question, "rights-030 question must mention 일반 국세")
    assert_equal "중", item.priority
    assert_equal false, item.yes_means_safe
    assert_equal "rights_analysis", item.tab
  end

  test "rights-008 and rights-030 ask distinct questions about separable tax categories" do
    rights_008 = InspectionItem.find_by!(code: "rights-008")
    rights_030 = InspectionItem.find_by!(code: "rights-030")
    refute_equal rights_008.question, rights_030.question
  end

  test "rights-017 depends_on resolves to an existing checklist item" do
    item = InspectionItem.find_by!(code: "rights-017")
    parent_code = item.depends_on["code"]
    assert InspectionItem.exists?(code: parent_code),
           "rights-017 depends_on=#{parent_code.inspect} must resolve to a valid item"
  end

  test "권리분석 rights-* items have unique (tab, tab_position) combinations" do
    # Scoped to rights-* because eviction-004 and manual-001 share tab_position 13 in 권리분석 (pre-existing, tracked separately).
    rights_items = InspectionItem.where(tab: "rights_analysis").where("code LIKE ?", "rights-%")
    positions = rights_items.pluck(:tab_position)
    assert_equal positions.size, positions.uniq.size,
                 "duplicate tab_position among rights-* items in 권리분석: #{positions.tally.select { |_, n| n > 1 }}"
  end

  test "all checklist item codes are unique" do
    codes = InspectionItem.pluck(:code)
    assert_equal codes.size, codes.uniq.size,
                 "duplicate codes: #{codes.tally.select { |_, n| n > 1 }}"
  end
end
