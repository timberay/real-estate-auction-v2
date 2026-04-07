require "test_helper"

class InspectionItemTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    item = InspectionItem.new(
      code: "test-001",
      tab: "sale_document",
      tab_position: 1,
      category: "권리분석",
      question: "테스트 질문입니까?",
      priority: "상"
    )
    assert item.valid?
  end

  test "code is required and unique" do
    InspectionItem.create!(code: "unique-001", tab: "sale_document", tab_position: 1, category: "권리분석", question: "Q?", priority: "상")
    dup = InspectionItem.new(code: "unique-001", tab: "sale_document", tab_position: 2, category: "권리분석", question: "Q2?", priority: "상")
    assert_not dup.valid?
  end

  test "tab enum values" do
    item = InspectionItem.new(code: "enum-test", tab: "sale_document", tab_position: 1, category: "C", question: "Q?", priority: "상")
    assert item.sale_document?

    item.tab = "registry"
    assert item.registry?

    item.tab = "building_ledger"
    assert item.building_ledger?

    item.tab = "online"
    assert item.online?

    item.tab = "field_visit"
    assert item.field_visit?

    item.tab = "etc"
    assert item.etc?
  end

  test "question and category are required" do
    item = InspectionItem.new(code: "test-002", tab: "sale_document", tab_position: 1, question: nil, category: nil, priority: "상")
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
    sale_items = InspectionItem.for_tab(:sale_document)
    assert sale_items.all?(&:sale_document?)
  end
end
