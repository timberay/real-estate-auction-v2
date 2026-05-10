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

  test "snapshots prior AI state into versions before overwriting" do
    # Seed an AI result so the mapper has something to overwrite.
    item = InspectionItem.find_by!(code: "rights-002")
    prior = InspectionResult.find_or_initialize_by(
      property: @property, inspection_item: item, user: @user
    )
    prior.update!(
      source_type: "ai",
      has_risk: false,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "이전 판단" }
    )

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    versions = prior.reload.versions.order(:version_number)
    assert_equal 1, versions.size
    snapshot = versions.first
    assert_equal 1, snapshot.version_number
    assert_equal "ai", snapshot.source_type
    assert_equal false, snapshot.has_risk
    assert_equal "이전 판단", snapshot.evidence["reasoning"]
    assert_not_nil snapshot.snapshotted_at
  end

  test "skips overwrite when report user_confirmed_at is set" do
    item = InspectionItem.find_by!(code: "rights-002")
    prior = InspectionResult.find_or_initialize_by(
      property: @property, inspection_item: item, user: @user
    )
    prior.update!(
      source_type: "ai",
      has_risk: false,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "확정된 판단" }
    )

    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.assign_attributes(analyzed_at: Time.current, user_confirmed_at: Time.current)
    report.save!(validate: false)

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    refreshed = prior.reload
    assert_equal false, refreshed.has_risk, "confirmed AI result must not be overwritten"
    assert_equal "확정된 판단", refreshed.evidence["reasoning"]
    assert_equal 0, refreshed.versions.count, "no snapshot when nothing was overwritten"
  end

  test "still overwrites when report exists but user_confirmed_at is nil" do
    item = InspectionItem.find_by!(code: "rights-002")
    prior = InspectionResult.find_or_initialize_by(
      property: @property, inspection_item: item, user: @user
    )
    prior.update!(
      source_type: "ai",
      has_risk: false,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "이전 판단" }
    )

    # @property already has risky_villa_report fixture with user_confirmed_at: nil — verify.
    report = RightsAnalysisReport.find_by(user: @user, property: @property)
    assert_nil report&.user_confirmed_at

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    refreshed = prior.reload
    # The fixture response asserts has_risk=true for rights-002, so we know overwrite ran.
    assert_equal true, refreshed.has_risk
    assert_equal 1, refreshed.versions.count
  end

  test "manual results still short-circuit regardless of confirmation" do
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.assign_attributes(analyzed_at: Time.current, user_confirmed_at: Time.current)
    report.save!(validate: false)

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    result = find_result("manual-001")
    assert result.manual?
    assert_equal "임차인과 협의 완료", result.resolution_note
    assert_equal 0, result.versions.count
  end

  test "applicable_for? override does not run when report is confirmed" do
    finance_item = InspectionItem.create!(
      code: "finance-007", tab: :profit_analysis, tab_position: 7,
      category: "자금&대출 분석",
      question: "등기부등본에 근저당 설정 이력이 있습니까?",
      applicable_types: [ "아파트" ],
      yes_means_safe: true
    )
    prior = InspectionResult.create!(
      property: @property, inspection_item: finance_item, user: @user,
      source_type: "ai", has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "확정 의견" }
    )

    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.assign_attributes(analyzed_at: Time.current, user_confirmed_at: Time.current)
    report.save!(validate: false)

    response_with_detached = @response.deep_dup
    response_with_detached["metadata"]["property_type"] = "단독주택"
    response_with_detached["results"]["finance-007"] = {
      "has_risk" => false, "confidence" => "high", "reasoning" => "신규 의견"
    }

    Inspection::InspectionResultMapper.call(
      response: response_with_detached, property: @property, user: @user,
      items: @items.to_a + [ finance_item ]
    )

    refreshed = prior.reload
    assert_equal true, refreshed.has_risk, "confirmed AI result must not be touched by applicable_for? override"
    assert_equal "확정 의견", refreshed.evidence["reasoning"]
    assert_equal 0, refreshed.versions.count
  ensure
    finance_item&.destroy
  end

  test "creates no version when AI result is first persisted" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )

    result = find_result("rights-002")
    assert result.ai?
    assert_equal 0, result.versions.count, "first persist should not snapshot"
  end

  test "version_number increments correctly across multiple overwrites" do
    item = InspectionItem.find_by!(code: "rights-002")
    prior = InspectionResult.find_or_initialize_by(
      property: @property, inspection_item: item, user: @user
    )
    prior.update!(
      source_type: "ai", has_risk: false,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "v0" }
    )

    response_a = @response.deep_dup
    response_a["results"]["rights-002"] = {
      "has_risk" => true, "confidence" => "high", "reasoning" => "v1"
    }
    response_b = @response.deep_dup
    response_b["results"]["rights-002"] = {
      "has_risk" => false, "confidence" => "high", "reasoning" => "v2"
    }

    Inspection::InspectionResultMapper.call(
      response: response_a, property: @property, user: @user, items: @items
    )
    Inspection::InspectionResultMapper.call(
      response: response_b, property: @property, user: @user, items: @items
    )

    versions = prior.reload.versions.order(:version_number)
    assert_equal [ 1, 2 ], versions.pluck(:version_number)
    assert_equal "v0", versions.first.evidence["reasoning"], "v1 snapshot captures prior v0 state"
    assert_equal "v1", versions.second.evidence["reasoning"], "v2 snapshot captures prior v1 state"
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
