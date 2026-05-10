require "test_helper"

class InspectionResultVersionTest < ActiveSupport::TestCase
  setup do
    @result = InspectionResult.create!(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_005),
      user: users(:guest),
      source_type: "ai",
      has_risk: false,
      evidence: { "source_label" => "AI 분석", "confidence" => "high" }
    )
  end

  test "valid with required attributes" do
    version = InspectionResultVersion.new(
      inspection_result: @result,
      version_number: 1,
      snapshotted_at: Time.current
    )
    assert version.valid?
  end

  test "requires inspection_result" do
    version = InspectionResultVersion.new(version_number: 1, snapshotted_at: Time.current)
    assert_not version.valid?
  end

  test "requires version_number" do
    version = InspectionResultVersion.new(inspection_result: @result, snapshotted_at: Time.current)
    assert_not version.valid?
  end

  test "version_number must be greater than 0" do
    version = InspectionResultVersion.new(
      inspection_result: @result,
      version_number: 0,
      snapshotted_at: Time.current
    )
    assert_not version.valid?
  end

  test "source_type enum mirrors InspectionResult" do
    version = InspectionResultVersion.new(source_type: "auto")
    assert version.auto?
    version.source_type = "manual"
    assert version.manual?
    version.source_type = "ai"
    assert version.ai?
    assert_equal 0, InspectionResultVersion.source_types["auto"]
    assert_equal 1, InspectionResultVersion.source_types["manual"]
    assert_equal 2, InspectionResultVersion.source_types["ai"]
  end

  test "version_number must be unique per inspection_result" do
    InspectionResultVersion.create!(
      inspection_result: @result,
      version_number: 1,
      snapshotted_at: Time.current
    )
    dup = InspectionResultVersion.new(
      inspection_result: @result,
      version_number: 1,
      snapshotted_at: Time.current
    )
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end
end
