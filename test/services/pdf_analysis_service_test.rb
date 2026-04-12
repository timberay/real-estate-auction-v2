require "test_helper"

class PdfAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    ENV["USE_MOCK"] = "true"
    @user = users(:guest)
    @property = properties(:safe_apartment)
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

  test "Path 2: creates property from metadata when documents provided directly" do
    docs = [ @pdf_blob ]
    result = PdfAnalysisService.call(documents: docs, user: @user)

    assert result.success?
    assert result.property.persisted?
    # Mock fixture returns case_number "2024타경12345"
    assert_equal "2024타경12345", result.property.case_number
  end

  test "Path 2: attaches documents to found/created property" do
    docs = [ @pdf_blob ]
    result = PdfAnalysisService.call(documents: docs, user: @user)

    assert result.property.documents.attached?
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

  test "report creation is idempotent on re-analysis" do
    PdfAnalysisService.call(property: @property, user: @user)
    PdfAnalysisService.call(property: @property, user: @user)

    assert_equal 1, RightsAnalysisReport.where(property: @property, user: @user).count
  end
end
