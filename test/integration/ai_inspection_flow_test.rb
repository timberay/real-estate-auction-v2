require "test_helper"

class AiInspectionFlowTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "full AI inspection pipeline: data assembly → prompt → mock LLM → DB mapping" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    PropertyInspectionService.call(property: @property, user: @user)

    # Verify AI results were created
    ai_results = InspectionResult.where(
      property: @property, user: @user, source_type: :ai
    )
    assert ai_results.count > 0, "Expected AI results to be created"

    # Verify high confidence result
    rights_002 = find_result("rights-002")
    assert rights_002.ai?
    assert rights_002.has_risk
    assert_equal "AI 분석", rights_002.evidence["source_label"]
    assert rights_002.evidence["reasoning"].present?

    # Verify manual answer preserved
    manual = find_result("manual-001")
    assert manual.manual?
  end

  test "fallback to InspectionRunner when USE_MOCK is false and no API key" do
    ENV.delete("USE_MOCK")
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    PropertyInspectionService.call(property: @property, user: @user)

    # Should have auto results from InspectionRunner fallback
    rights_011 = find_result("rights-011")
    assert rights_011.auto?
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
