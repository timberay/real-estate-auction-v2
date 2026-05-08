require "test_helper"
require Rails.root.join("db/migrate/20260508013259_reorganize_checklist_items_2026_05.rb")

class ReorganizeChecklistItems202605Test < ActiveSupport::TestCase
  include ChecklistSeedHelper

  setup do
    load_checklist_seed!
  end

  test "up is idempotent — re-running produces same state" do
    initial_count = InspectionItem.count
    ReorganizeChecklistItems202605.new.up
    assert_equal initial_count, InspectionItem.count
    assert_equal "field_check", InspectionItem.find_by(code: "inspect-005").tab
    assert_nil InspectionItem.find_by(code: "tax-007")
  end

  test "transaction rolls back if migration step fails mid-up" do
    # The seed JSON already reflects the post-reorganization state, so the
    # migration's CHANGES would be no-ops as-is. Diverge a few rows so the
    # earlier CHANGES have real work to do, then force a LATER change to
    # raise — this proves the earlier update!s rolled back when the
    # migration's transaction aborted, not just that nothing happened.
    InspectionItem.find_by!(code: "inspect-005").update!(tab: "profit_analysis")
    InspectionItem.find_by!(code: "inspect-009").update!(question: "OLD QUESTION")
    # Re-create tax-007 so DELETIONS would have something to destroy if reached.
    InspectionItem.create!(
      code: "tax-007",
      tab: "profit_analysis",
      tab_position: 99,
      category: "세무&절세 분석",
      question: "should remain after rollback",
      priority: "중"
    )

    pre_inspect_005_tab = "profit_analysis"
    pre_inspect_009_question = "OLD QUESTION"
    pre_count = InspectionItem.count

    # Force the THIRD CHANGE (eviction-001) to raise. The first two updates
    # (inspect-005, inspect-009) have already happened inside the migration's
    # transaction by then — if rollback works, those two updates are reverted
    # AND tax-007 is NOT deleted (DELETIONS runs after CHANGES).
    failure_module = Module.new do
      def update!(*args, **kwargs)
        if code == "eviction-001"
          raise StandardError, "forced failure inside migration transaction"
        end
        super
      end
    end
    InspectionItem.prepend(failure_module)

    begin
      assert_raises(StandardError) do
        ReorganizeChecklistItems202605.new.up
      end
    ensure
      failure_module.remove_method(:update!)
    end

    # Earlier CHANGES rolled back to their pre-migration (diverged) values.
    assert_equal pre_inspect_005_tab, InspectionItem.find_by!(code: "inspect-005").tab,
      "inspect-005 update should have rolled back when later CHANGE raised"
    assert_equal pre_inspect_009_question, InspectionItem.find_by!(code: "inspect-009").question,
      "inspect-009 update should have rolled back when later CHANGE raised"
    # DELETIONS never ran.
    assert_equal pre_count, InspectionItem.count
    assert_not_nil InspectionItem.find_by(code: "tax-007"),
      "tax-007 should still exist; DELETIONS should not have run after rollback"
  end

  test "deleting tax-007 cascades to inspection_results via the migration" do
    user = users(:guest)
    property = properties(:safe_apartment)

    # The seed JSON no longer contains tax-007 (it's a post-reorganization
    # state). Re-create a fresh tax-007 so the migration's DELETIONS path has
    # something to destroy.
    tax_item = InspectionItem.create!(
      code: "tax-007",
      tab: "profit_analysis",
      tab_position: 99,
      category: "세무&절세 분석",
      question: "test question",
      priority: "중"
    )
    result = InspectionResult.create!(user: user, property: property, inspection_item: tax_item)

    ReorganizeChecklistItems202605.new.up

    assert_nil InspectionItem.find_by(code: "tax-007"),
      "migration's DELETIONS path should destroy tax-007"
    assert_nil InspectionResult.find_by(id: result.id),
      "destroying tax-007 should cascade via dependent: :destroy"
  end
end
