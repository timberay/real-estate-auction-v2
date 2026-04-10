require "test_helper"

class AiInspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "creates inspection results for all rights_analysis items" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    items = InspectionItem.where(tab: :rights_analysis)
    items.each do |item|
      result = InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
      assert_not_nil result, "Missing result for #{item.code}"
    end
  end

  test "sets source_type to ai for high confidence results" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("rights-002")
    assert result.ai?
    assert result.has_risk
    assert_equal "AI 분석", result.evidence["source_label"]
  end

  test "preserves manual answers" do
    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("manual-001")
    assert result.manual?
  end

  test "is idempotent — running twice does not create duplicates" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_first = InspectionResult.where(property: @property, user: @user).count

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_second = InspectionResult.where(property: @property, user: @user).count

    assert_equal count_after_first, count_after_second
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
