require "test_helper"

class PropertyCheckResultTest < ActiveSupport::TestCase
  test "valid with property, checklist_item, and user" do
    result = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_011),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "property, checklist_item, and user combination must be unique" do
    PropertyCheckResult.create!(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    dup = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002),
      user: users(:guest)
    )
    assert_not dup.valid?
  end

  test "different users can have results for same property and checklist_item" do
    PropertyCheckResult.create!(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    result_budget_user = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002),
      user: users(:budget_user),
      source_type: "auto",
      has_risk: false
    )
    assert result_budget_user.valid?
  end

  test "source_type enum" do
    result = PropertyCheckResult.new(source_type: "auto")
    assert result.auto?
    result.source_type = "manual"
    assert result.manual?
  end

  test "resolvable is nil by default" do
    result = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:property_004),
      user: users(:guest),
      source_type: "auto",
      has_risk: true
    )
    assert_nil result.resolvable
  end
end
