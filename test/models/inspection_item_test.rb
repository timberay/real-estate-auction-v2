require "test_helper"

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

    item.tab = "property_analysis"
    assert item.property_analysis?

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
      tab: "property_analysis",
      tab_position: 1,
      category: "물건분석",
      question: "특정 타입에만 적용?",
      priority: "중",
      applicable_types: ["아파트", "오피스텔"]
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
      applicable_types: ["아파트"]
    )
    refute item.applicable_for?("단독주택")
  end
end
