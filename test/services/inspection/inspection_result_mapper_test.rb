require "test_helper"

class Inspection::InspectionResultMapperTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    @items = InspectionItem.where(tab: :rights_analysis).ordered
    @response = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))
  end

  test "creates inspection results for high confidence items" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-002")
    assert result.ai?
    assert result.has_risk
    assert_equal "high", result.evidence["confidence"]
    assert result.evidence["reasoning"].present?
    assert_equal "AI 분석", result.evidence["source_label"]
  end

  test "creates inspection results for medium confidence items" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-001")
    assert result.ai?
    assert_equal false, result.has_risk
    assert_equal "medium", result.evidence["confidence"]
    assert_equal "AI 분석 (추론)", result.evidence["source_label"]
  end

  test "does not overwrite manual answers" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("manual-001")
    assert result.manual?
    assert result.has_risk
    assert_equal "임차인과 협의 완료", result.resolution_note
  end

  test "overwrites previous auto answers with ai" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-011")
    assert result.ai?
  end

  test "preserves AI reasoning even when confidence is none" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-009")
    assert_nil result.has_risk
    assert result.evidence.present?, "evidence should be preserved for none confidence"
    assert_equal "none", result.evidence["confidence"]
    assert_equal "AI 분석 (참고)", result.evidence["source_label"]
    assert result.evidence["reasoning"].present?
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
