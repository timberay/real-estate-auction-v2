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

  test "stores tenants and rights_timeline in report_data" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal 2, report.report_data["tenants"].size
    assert_equal 3, report.report_data["rights_timeline"].size
    assert report.report_data["reasoning"].present?
  end

  test "creates extraction_failed report when rights_analysis key is missing" do
    fixture_path = Rails.root.join("test/fixtures/files/ai_inspection_response.json")
    original = File.read(fixture_path)
    no_rights = JSON.parse(original).except("rights_analysis")
    File.write(fixture_path, JSON.generate(no_rights))

    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_not_nil report
    assert_equal "extraction_failed", report.report_data["analysis_status"]
  ensure
    File.write(fixture_path, original)
  end

  test "report creation is idempotent on re-analysis" do
    PdfAnalysisService.call(property: @property, user: @user)
    PdfAnalysisService.call(property: @property, user: @user)

    assert_equal 1, RightsAnalysisReport.where(property: @property, user: @user).count
  end
end
