require "test_helper"
require Rails.root.join("db/migrate/20260508013259_reorganize_checklist_items_2026_05.rb")

class ReorganizeChecklistItems202605Test < ActiveSupport::TestCase
  TAB_MAP = {
    "권리분석" => "rights_analysis",
    "수익분석" => "profit_analysis",
    "현장확인" => "field_check",
    "입찰&낙찰" => "bidding"
  }.freeze

  setup do
    InspectionResult.delete_all
    InspectionItem.delete_all
    json_path = Rails.root.join("db/seeds/checklist_items_summary.json")
    JSON.parse(File.read(json_path)).each do |attrs|
      tab_key = TAB_MAP[attrs["tab"]]
      next unless tab_key
      InspectionItem.create!(
        code: attrs["id"],
        tab: tab_key,
        tab_position: attrs["tab_position"],
        category: attrs["category"],
        question: attrs["question"],
        description: attrs["description"],
        logic: attrs["logic"],
        priority: attrs["priority"],
        merged_from: attrs["merged_from"],
        answer_type: attrs["answer_type"],
        yes_means_safe: attrs.fetch("yes_means_safe", true),
        applicable_types: attrs["applicable_types"],
        depends_on: attrs["depends_on"]
      )
    end
  end

  test "up is idempotent — re-running produces same state" do
    initial_count = InspectionItem.count
    ReorganizeChecklistItems202605.new.up
    assert_equal initial_count, InspectionItem.count
    assert_equal "field_check", InspectionItem.find_by(code: "inspect-005").tab
    assert_nil InspectionItem.find_by(code: "tax-007")
  end

  test "transaction rolls back if any step fails" do
    original = InspectionItem.find_by!(code: "inspect-005").tab

    assert_raises(ActiveRecord::RecordNotFound) do
      ActiveRecord::Base.transaction do
        InspectionItem.find_by!(code: "inspect-005").update!(tab: "rights_analysis")
        InspectionItem.find_by!(code: "nonexistent-code-xyz")
      end
    end

    assert_equal original, InspectionItem.find_by!(code: "inspect-005").tab
  end

  test "deleting an item cascades to inspection_results" do
    user = users(:guest)
    property = properties(:safe_apartment)
    tax_item = InspectionItem.find_or_create_by!(code: "tax-007-temp") do |i|
      i.tab = "profit_analysis"
      i.category = "세무&절세 분석"
      i.question = "test"
      i.priority = "중"
    end
    InspectionResult.create!(user: user, property: property, inspection_item: tax_item)

    assert_difference "InspectionResult.count", -1 do
      tax_item.destroy
    end
  end
end
