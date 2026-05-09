require "test_helper"

class PdfAnalysisServiceTest < ActiveSupport::TestCase
  # Mock LLM fixture always returns case_number "2024타경12345".
  # @property must match so the mismatch check passes for general tests.
  MOCK_CASE_NUMBER = "2024타경12345"

  setup do
    ENV["USE_MOCK"] = "true"
    @user = users(:guest)
    @property = Property.create!(case_number: MOCK_CASE_NUMBER)
    @pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test content"),
      filename: "test_doc.pdf",
      content_type: "application/pdf"
    )
    @property.documents.attach(@pdf_blob)
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "Path 1: analyzes property with attached documents" do
    result = PdfAnalysisService.call(property: @property, user: @user)

    assert result.success?
    assert @property.inspection_results.where(user: @user).any?
  end

  test "Path 1: creates LlmAnalysisLog" do
    assert_difference "LlmAnalysisLog.count", 1 do
      PdfAnalysisService.call(property: @property, user: @user)
    end

    log = LlmAnalysisLog.last
    assert_equal @property.id, log.property_id
    assert_equal "completed", log.status
  end

  test "Path 1: fails when no documents attached" do
    property_no_docs = Property.create!(case_number: "2024타경999")
    result = PdfAnalysisService.call(property: property_no_docs, user: @user)

    assert_not result.success?
    assert_equal "문서를 먼저 업로드해주세요.", result.error
  end

  test "Path 2: finds property by case_number from LLM metadata when documents provided directly" do
    # @property already has case_number matching mock fixture ("2024타경12345")
    result = PdfAnalysisService.call(property: @property, documents: [ @pdf_blob ], user: @user)

    assert result.success?
    assert_equal @property.id, result.property.id
  end

  test "Path 2: attaches documents to found property" do
    result = PdfAnalysisService.call(property: @property, documents: [ @pdf_blob ], user: @user)

    assert result.property.documents.attached?
  end

  test "raises CaseNumberMissingError when no property given and LLM returns no case_number" do
    mock_llm = Llm::Mock.new
    mock_llm.override_response = { "metadata" => {}, "results" => [] }
    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    docs = [ @pdf_blob ]
    assert_raises(PdfAnalysisService::CaseNumberMissingError) do
      PdfAnalysisService.call(documents: docs, user: @user)
    end
    assert_equal 0, Property.where("case_number LIKE 'PDF-%'").count
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "raises CaseNumberMismatchError when LLM extracts a different case_number than provided property" do
    # Mock fixture returns "2024타경12345"; this property has a different case_number
    other_property = properties(:safe_apartment)  # case_number "2026타경10001"
    other_property.documents.attach(@pdf_blob)
    assert_raises(PdfAnalysisService::CaseNumberMismatchError) do
      PdfAnalysisService.call(property: other_property, user: @user)
    end
  end

  test "raises error for unsupported LLM provider" do
    ENV["USE_MOCK"] = nil
    ENV["LLM_PROVIDER"] = "ollama"

    error = assert_raises(RuntimeError) do
      PdfAnalysisService.call(property: @property, user: @user)
    end
    assert_includes error.message, "PDF 분석을 지원하지 않습니다"
  ensure
    ENV["LLM_PROVIDER"] = nil
    ENV["USE_MOCK"] = "true"
  end

  test "creates RightsAnalysisReport from LLM rights_analysis response" do
    result = PdfAnalysisService.call(property: @property, user: @user)

    assert result.success?

    report = RightsAnalysisReport.find_by(property: result.property, user: @user)
    assert_not_nil report
    assert_equal "caution", report.verdict
    assert_equal "근저당권", report.base_right_type
    assert_equal "○○은행", report.base_right_holder
    assert_equal Date.parse("2024-01-15"), report.base_right_date
  end

  test "calculates assumed_amount from rights_timeline in Ruby" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    # All 3 rights have extinguished_on_sale: true → assumed_amount = 0
    assert_equal 0, report.assumed_amount
  end

  test "calculates total_risk_amount from assumed_amount plus opposing tenants" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    # assumed_amount(0) + opposing tenant 김○○ deposit(50_000_000) = 50_000_000
    assert_equal 50_000_000, report.total_risk_amount
  end

  test "stores report_data with llm_raw, calculated, and discrepancies" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal 2, report.report_data["llm_raw"]["tenants"].size
    assert_equal 3, report.report_data["llm_raw"]["rights_timeline"].size
    assert report.report_data["llm_raw"]["reasoning"].present?
    assert_equal 2, report.report_data["calculated"]["tenants"].size
    assert report.report_data["discrepancies"].is_a?(Array)
  end

  test "calculated tenants have opposing_power recalculated by Ruby" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    tenants = report.report_data["calculated"]["tenants"]
    kim = tenants.find { |t| t["name"] == "김○○" }
    park = tenants.find { |t| t["name"] == "박○○" }

    assert_equal true, kim["opposing_power"]
    assert_equal true, kim["has_priority_repayment"]
    assert_equal false, park["opposing_power"]
    assert_equal true, park["has_priority_repayment"]
  end

  test "calculated amounts use Ruby values" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    amounts = report.report_data["calculated"]
    assert_equal 0, amounts["assumed_amount"]
    assert_equal 50_000_000, amounts["opposing_deposits"]
    assert_equal 50_000_000, amounts["total_risk_amount"]
  end

  test "DB columns match Ruby-calculated values" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal report.report_data.dig("calculated", "assumed_amount"), report.assumed_amount
    assert_equal report.report_data.dig("calculated", "total_risk_amount"), report.total_risk_amount
  end

  test "stores opportunity_type from LLM response" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal "hug_waiver", report.opportunity_type
    assert report.opportunity_reason.present?
  end

  # --- B8 / E-41: hug_waiver server-side citation enforcement ---

  test "preserves opportunity_type=hug_waiver when all citation fields present" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    # Mock fixture provides opportunity_source_doc / opportunity_page_number / opportunity_quote
    assert_equal "hug_waiver", report.opportunity_type
    evidence = report.parsed_data["opportunity_evidence"]
    assert_not_nil evidence, "opportunity_evidence must be stored in report_data"
    assert evidence["source_doc"].present?
    assert evidence["page_number"].present?
    assert evidence["quote"].present?
  end

  test "nulls opportunity_type when hug_waiver returned without complete citation" do
    incomplete = JSON.parse(File.read(Llm::Mock::FIXTURE_PATH))
    incomplete["rights_analysis"]["opportunity_type"] = "hug_waiver"
    incomplete["rights_analysis"]["opportunity_source_doc"] = nil
    incomplete["rights_analysis"]["opportunity_page_number"] = 5
    incomplete["rights_analysis"]["opportunity_quote"] = "원문 인용 문장"

    mock_llm = Llm::Mock.new
    mock_llm.override_response = incomplete
    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_nil report.opportunity_type, "opportunity_type must be nulled when citation incomplete"
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "preserves non-hug_waiver opportunity_type without citation fields" do
    response = JSON.parse(File.read(Llm::Mock::FIXTURE_PATH))
    response["rights_analysis"]["opportunity_type"] = "gap_investment"
    response["rights_analysis"]["opportunity_source_doc"] = nil
    response["rights_analysis"]["opportunity_page_number"] = nil
    response["rights_analysis"]["opportunity_quote"] = nil

    mock_llm = Llm::Mock.new
    mock_llm.override_response = response
    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    # gap_investment does not require citation — guard must be hug_waiver-specific
    assert_equal "gap_investment", report.opportunity_type
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "stores opportunity_evidence in report_data for hug_waiver" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    evidence = report.parsed_data["opportunity_evidence"]
    assert_not_nil evidence
    assert evidence["source_doc"].is_a?(String)
    assert evidence["page_number"].is_a?(Integer)
    assert evidence["quote"].is_a?(String)
  end

  test "effective_tenants helper returns calculated tenants" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal report.report_data["calculated"]["tenants"], report.effective_tenants
  end

  test "creates extraction_failed report when rights_analysis key is missing" do
    original = JSON.parse(File.read(Llm::Mock::FIXTURE_PATH))
    no_rights = original.except("rights_analysis")

    mock_llm = Llm::Mock.new
    mock_llm.override_response = no_rights

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_not_nil report
    assert_equal "extraction_failed", report.report_data["analysis_status"]
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "stores failure_reason when rights_analysis key is missing" do
    original = JSON.parse(File.read(Llm::Mock::FIXTURE_PATH))
    no_rights = original.except("rights_analysis")

    mock_llm = Llm::Mock.new
    mock_llm.override_response = no_rights

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_not_nil report.report_data["failure_reason"]
    assert_match(/rights_analysis/, report.report_data["failure_reason"])
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "stores failure_reason on JSON::ParserError" do
    mock_llm = Object.new
    mock_llm.define_singleton_method(:analyze) { |**_| raise JSON::ParserError, "unexpected token" }
    mock_llm.define_singleton_method(:provider_name) { "mock" }
    mock_llm.define_singleton_method(:model_id) { "mock-1" }

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    assert_raises(JSON::ParserError) do
      PdfAnalysisService.call(property: @property, user: @user)
    end

    report = RightsAnalysisReport.find_by(property: @property, user: @user)
    assert_not_nil report
    assert_equal "extraction_failed", report.report_data["analysis_status"]
    assert_match(/JSON 파싱/, report.report_data["failure_reason"])
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "stores failure_reason on Faraday::TimeoutError" do
    mock_llm = Object.new
    mock_llm.define_singleton_method(:analyze) { |**_| raise Faraday::TimeoutError, "timed out" }
    mock_llm.define_singleton_method(:provider_name) { "mock" }
    mock_llm.define_singleton_method(:model_id) { "mock-1" }

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    assert_raises(Faraday::TimeoutError) do
      PdfAnalysisService.call(property: @property, user: @user)
    end

    report = RightsAnalysisReport.find_by(property: @property, user: @user)
    assert_not_nil report
    assert_equal "extraction_failed", report.report_data["analysis_status"]
    assert_match(/시간 초과/, report.report_data["failure_reason"])
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "does not crash when failure occurs before property is resolved" do
    # No @property given (case_number-first flow); LLM raises before resolve.
    mock_llm = Object.new
    mock_llm.define_singleton_method(:analyze) { |**_| raise StandardError, "early failure" }
    mock_llm.define_singleton_method(:provider_name) { "mock" }
    mock_llm.define_singleton_method(:model_id) { "mock-1" }

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { mock_llm }

    # Should re-raise without crashing and without writing a new report
    # (no property to attach the report to).
    initial_report_ids = RightsAnalysisReport.pluck(:id)
    assert_raises(StandardError) do
      PdfAnalysisService.call(documents: [ @pdf_blob ], user: @user)
    end
    assert_equal initial_report_ids.sort, RightsAnalysisReport.pluck(:id).sort
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "report creation is idempotent on re-analysis" do
    PdfAnalysisService.call(property: @property, user: @user)
    PdfAnalysisService.call(property: @property, user: @user)

    assert_equal 1, RightsAnalysisReport.where(property: @property, user: @user).count
  end

  test "Path 3: processes user-provided JSON without LLM call" do
    response_json = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))

    result = PdfAnalysisService.call(response_json: response_json, user: @user)

    assert result.success?
    assert result.property.persisted?
    assert_equal "2024타경12345", result.property.case_number
    assert result.property.inspection_results.where(user: @user).any?
  end

  test "find_by case_number is space-insensitive on lookup" do
    # DB record has spaces; LLM returns compact form — find_by! must still match
    property = Property.create!(case_number: "2024 타경 99999")
    service = PdfAnalysisService.new(property: nil, documents: nil, user: @user)
    metadata = { "case_number" => "2024타경99999" }

    found = service.send(:resolve_property, metadata)

    assert_equal property.id, found.id
  end

  test "Path 3: logs analysis with provider manual and model user_input" do
    response_json = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))

    assert_difference "LlmAnalysisLog.count", 1 do
      PdfAnalysisService.call(response_json: response_json, user: @user)
    end

    log = LlmAnalysisLog.last
    assert_equal "manual", log.provider
    assert_equal "user_input", log.model
    assert_equal "manual_upload", log.system_prompt
    assert_equal "completed", log.status
  end
end
