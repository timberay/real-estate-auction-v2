require "test_helper"

class PropertyCheckResultTest < ActiveSupport::TestCase
  test "valid with property and checklist_item" do
    result = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_011),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "property and checklist_item combination must be unique" do
    PropertyCheckResult.create!(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002),
      source_type: "auto",
      has_risk: false
    )
    dup = PropertyCheckResult.new(
      property: properties(:unanalyzed_officetel),
      checklist_item: checklist_items(:rights_002)
    )
    assert_not dup.valid?
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
      source_type: "auto",
      has_risk: true
    )
    assert_nil result.resolvable
  end
end
