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

  test "demotes medium confidence has_risk=false to nil for user confirmation" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-001")
    assert result.ai?
    assert_nil result.has_risk, "medium + has_risk=false should be demoted to nil"
    assert_equal "medium", result.evidence["confidence"]
    assert_equal "AI 의견 (확인 필요)", result.evidence["source_label"]
    assert result.evidence["reasoning"].present?, "reasoning should still be preserved in evidence"
  end

  test "preserves medium confidence has_risk=true so user still sees flagged risk" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    response_with_medium_true = @response.deep_dup
    response_with_medium_true["results"]["rights-002"] = {
      "has_risk" => true,
      "confidence" => "medium",
      "reasoning" => "추정으로 위험 신호가 보입니다."
    }

    Inspection::InspectionResultMapper.call(
      response: response_with_medium_true, property: @property, user: @user, items: @items
    )
    result = find_result("rights-002")
    assert result.ai?
    assert_equal true, result.has_risk, "medium + has_risk=true should be preserved (not demoted)"
    assert_equal "medium", result.evidence["confidence"]
    assert_equal "AI 분석 (추론)", result.evidence["source_label"]
  end

  test "preserves high confidence has_risk=false unchanged" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-019")
    assert result.ai?
    assert_equal false, result.has_risk
    assert_equal "high", result.evidence["confidence"]
    assert_equal "AI 분석", result.evidence["source_label"]
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
    result = find_result("rights-003")
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

  test "passes source_doc / page_number / quote citation fields through to evidence" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    response_with_citations = @response.deep_dup
    response_with_citations["results"]["rights-001"] = {
      "has_risk" => false,
      "confidence" => "medium",
      "reasoning" => "매각물건명세서에 가처분 관련 기재가 없습니다.",
      "source_doc" => "매각물건명세서",
      "page_number" => 2,
      "quote" => "비고란에 가처분, 가등기 등 추가 권리에 관한 기재 사항이 없음을 확인하였습니다."
    }

    Inspection::InspectionResultMapper.call(
      response: response_with_citations, property: @property, user: @user, items: @items
    )

    result = find_result("rights-001")
    assert_equal "매각물건명세서", result.evidence["source_doc"]
    assert_equal 2, result.evidence["page_number"]
    assert_includes result.evidence["quote"], "가처분"
  end

  test "citation keys exist (with nil values) when AI omits them" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    # rights-002 in fixture has no citation fields; mapper should still include the keys.
    result = find_result("rights-002")
    assert result.evidence.key?("source_doc"), "evidence should always carry source_doc key"
    assert result.evidence.key?("page_number"), "evidence should always carry page_number key"
    assert result.evidence.key?("quote"), "evidence should always carry quote key"
    assert_nil result.evidence["source_doc"]
    assert_nil result.evidence["page_number"]
    assert_nil result.evidence["quote"]
  end

  test "citation passthrough also works for none confidence (with reasoning)" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    response_with_citation_none = @response.deep_dup
    response_with_citation_none["results"]["rights-009"] = {
      "has_risk" => nil,
      "confidence" => "none",
      "reasoning" => "관련 정보가 부족합니다.",
      "source_doc" => "등기부등본",
      "page_number" => 1,
      "quote" => "을구에 HUG 관련 기재 사항이 없는 것으로 확인되었습니다."
    }

    Inspection::InspectionResultMapper.call(
      response: response_with_citation_none, property: @property, user: @user, items: @items
    )

    result = find_result("rights-009")
    assert_nil result.has_risk
    assert_equal "등기부등본", result.evidence["source_doc"]
    assert_equal 1, result.evidence["page_number"]
    assert_includes result.evidence["quote"], "HUG"
  end

  test "overrides has_risk to nil for items not applicable to property type" do
    finance_item = InspectionItem.create!(
      code: "finance-003", tab: :profit_analysis, tab_position: 2,
      category: "자금&대출 분석",
      question: "등기부등본에 근저당 설정 이력이 있습니까?",
      applicable_types: [ "아파트" ],
      yes_means_safe: true
    )

    response_with_detached = @response.deep_dup
    response_with_detached["metadata"]["property_type"] = "단독주택"
    response_with_detached["results"]["finance-003"] = {
      "has_risk" => false, "confidence" => "high",
      "reasoning" => "근저당 설정 이력이 확인됩니다."
    }

    items_with_finance = @items.to_a + [ finance_item ]

    Inspection::InspectionResultMapper.call(
      response: response_with_detached, property: @property, user: @user, items: items_with_finance
    )

    result = InspectionResult.find_by(property: @property, inspection_item: finance_item, user: @user)
    assert_nil result.has_risk, "should override to nil for non-applicable property type"
    assert_equal "none", result.evidence["confidence"]
    assert_includes result.evidence["reasoning"], "단독주택"
  ensure
    finance_item&.destroy
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
