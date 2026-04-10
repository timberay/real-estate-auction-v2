require "test_helper"

class InspectionResultTest < ActiveSupport::TestCase
  test "valid with property, inspection_item, and user" do
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:property_004),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "property, inspection_item, and user combination must be unique" do
    InspectionResult.create!(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    dup = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest)
    )
    assert_not dup.valid?
  end

  test "different users can have results for same property and item" do
    InspectionResult.create!(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:budget_user),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "source_type enum" do
    result = InspectionResult.new(source_type: "auto")
    assert result.auto?
    result.source_type = "manual"
    assert result.manual?
  end

  test "source_type enum includes ai" do
    result = InspectionResult.new(source_type: :ai)
    assert result.ai?
    assert_equal 2, InspectionResult.source_types["ai"]
  end

  test "has_risk nil means unanswered" do
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:manual_001),
      user: users(:guest)
    )
    assert_nil result.has_risk
    assert_nil result.source_type
  end
end
