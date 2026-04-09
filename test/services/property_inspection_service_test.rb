require "test_helper"

class PropertyInspectionServiceTest < ActiveSupport::TestCase
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001").property
    @user = users(:guest)
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "creates inspection results for all items" do
    PropertyInspectionService.call(property: @property, user: @user)
    assert_equal InspectionItem.count, InspectionResult.where(property: @property, user: @user).count
  end

  test "creates rights analysis report" do
    PropertyInspectionService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: @property, user: @user)
    assert_not_nil report
    assert_not_nil report.analyzed_at
  end
end
