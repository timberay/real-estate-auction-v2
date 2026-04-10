require "test_helper"

class PropertyInspectionServiceTest < ActiveSupport::TestCase
  setup do
    @property = properties(:safe_apartment)
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

  test "uses AiInspectionRunner when USE_MOCK is true" do
    property = properties(:risky_villa)
    property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all
    ENV["USE_MOCK"] = "true"

    PropertyInspectionService.call(property: property, user: @user)

    item = InspectionItem.find_by(code: "rights-002")
    result = InspectionResult.find_by(property: property, inspection_item: item, user: @user)
    assert result.ai?, "Expected AI source_type but got #{result.source_type}"
  ensure
    ENV.delete("USE_MOCK")
  end

  test "falls back to InspectionRunner when AI fails" do
    property = properties(:risky_villa)
    property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all
    ENV.delete("USE_MOCK")
    saved_provider = ENV.delete("LLM_PROVIDER")
    saved_key = ENV.delete("GEMINI_API_KEY")

    PropertyInspectionService.call(property: property, user: @user)

    item = InspectionItem.find_by(code: "rights-011")
    result = InspectionResult.find_by(property: property, inspection_item: item, user: @user)
    assert result.auto?, "Expected auto source_type from fallback but got #{result.source_type}"
  ensure
    ENV["LLM_PROVIDER"] = saved_provider if saved_provider
    ENV["GEMINI_API_KEY"] = saved_key if saved_key
  end
end
