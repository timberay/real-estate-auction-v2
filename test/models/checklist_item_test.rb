require "test_helper"

class ChecklistItemTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    item = ChecklistItem.new(
      code: "test-001",
      category: "권리분석",
      risk_axis: "legal",
      question: "테스트 질문입니까?",
      description: "테스트 설명",
      data_source_name: "매각물건명세서",
      priority: "상",
      position: 1
    )
    assert item.valid?
  end

  test "code is required and unique" do
    item = ChecklistItem.new(code: nil)
    assert_not item.valid?
    assert_includes item.errors[:code], "can't be blank"
  end

  test "code uniqueness" do
    ChecklistItem.create!(code: "test-unique", category: "권리분석", risk_axis: "legal", question: "Q?", description: "D", data_source_name: "매각물건명세서", priority: "상", position: 99)
    dup = ChecklistItem.new(code: "test-unique", risk_axis: "legal", question: "Q2?")
    assert_not dup.valid?
  end

  test "risk_axis enum" do
    item = checklist_items(:rights_011)
    assert item.legal?
    item.risk_axis = "resale"
    assert item.resale?
    item.risk_axis = "loan"
    assert item.loan?
  end

  test "question is required" do
    item = ChecklistItem.new(code: "test-002", risk_axis: "legal", question: nil)
    assert_not item.valid?
    assert_includes item.errors[:question], "can't be blank"
  end

  test "scope by_risk_axis" do
    legal_items = ChecklistItem.legal
    assert legal_items.all? { |i| i.legal? }
  end

  test "ordered scope returns items by position" do
    items = ChecklistItem.ordered
    positions = items.map(&:position)
    assert_equal positions, positions.sort
  end
end
