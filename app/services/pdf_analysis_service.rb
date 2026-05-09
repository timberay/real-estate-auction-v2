class PdfAnalysisService
  Result = Struct.new(:success?, :property, :error, keyword_init: true)

  class CaseNumberMissingError < StandardError; end
  class CaseNumberMismatchError < StandardError; end

  def self.call(property: nil, documents: nil, user:, response_json: nil)
    new(property:, documents:, user:, response_json:).call
  end

  def initialize(property:, documents:, user:, response_json: nil)
    @property = property
    @documents = documents
    @user = user
    @response_json = response_json
  end

  def call
    if @response_json
      call_with_manual_json
    else
      call_with_llm
    end
  rescue => e
    log_failure(e)
    raise
  end

  private

  def call_with_llm
    pdf_blobs = collect_documents
    return Result.new(success?: false, error: "문서를 먼저 업로드해주세요.") if pdf_blobs.empty?

    items = if @property&.property_type.present?
      InspectionItem.applicable_for_type(@property.property_type).ordered
    else
      InspectionItem.ordered
    end
    prompts = Inspection::PdfPromptBuilder.call(items: items)

    llm = Llm::Base.for
    response = llm.analyze(
      system: prompts[:system],
      prompt: prompts[:user],
      documents: pdf_blobs
    )

    property = resolve_property(response["metadata"])
    attach_documents_to_property(property, pdf_blobs) if @property.nil?

    Inspection::InspectionResultMapper.call(
      response: response, property: property, user: @user, items: items
    )

    log_analysis(property, response, llm: llm, prompts: prompts)
    create_or_update_report(property, response)

    UserProperty.find_or_create_by!(user: @user, property: property)
    InspectionRatingService.call(property: property, user: @user)

    Result.new(success?: true, property: property)
  end

  def call_with_manual_json
    response = @response_json
    items = InspectionItem.ordered
    property = resolve_property(response["metadata"])

    Inspection::InspectionResultMapper.call(
      response: response, property: property, user: @user, items: items
    )

    log_analysis(property, response)
    create_or_update_report(property, response)

    UserProperty.find_or_create_by!(user: @user, property: property)
    InspectionRatingService.call(property: property, user: @user)

    Result.new(success?: true, property: property)
  end

  def collect_documents
    if @property
      @property.documents.map(&:blob)
    elsif @documents
      @documents
    else
      []
    end
  end

  def resolve_property(metadata)
    if @property
      llm_case = metadata&.dig("case_number").presence
      if llm_case && normalize_case(llm_case) != normalize_case(@property.case_number)
        raise CaseNumberMismatchError,
              "PDF에서 추출된 사건번호(#{llm_case})가 선택한 물건(#{@property.case_number})과 다릅니다."
      end
      @property
    else
      llm_case = metadata&.dig("case_number").presence
      raise CaseNumberMissingError, "사건번호를 먼저 입력해 주세요." if llm_case.blank?
      Property.find_by!(
        "LOWER(REPLACE(case_number, ' ', '')) = ?",
        normalize_case(llm_case)
      )
    end
  end

  def normalize_case(s)
    s.to_s.gsub(/\s+/, "").downcase
  end

  def attach_documents_to_property(property, blobs)
    blobs.each do |blob|
      property.documents.attach(blob) unless property.documents.blobs.include?(blob)
    end
  end

  def log_analysis(property, response, llm: nil, prompts: nil)
    if @response_json
      LlmAnalysisLog.create!(
        property: property,
        user: @user,
        provider: "manual",
        model: "user_input",
        system_prompt: "manual_upload",
        user_prompt: "manual_upload",
        response_json: response,
        status: :completed,
        executed_at: Time.current
      )
    else
      LlmAnalysisLog.create!(
        property: property,
        user: @user,
        provider: llm.provider_name,
        model: llm.model_id,
        system_prompt: prompts[:system],
        user_prompt: prompts[:user],
        response_json: response,
        status: :completed,
        executed_at: Time.current
      )
    end
  end

  def create_or_update_report(property, response)
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: property)
    rights_data = response["rights_analysis"]

    if rights_data.blank?
      report.update!(
        analyzed_at: Time.current,
        verdict_summary: nil,
        report_data: { "analysis_status" => "extraction_failed", "failed_at" => Time.current.iso8601 }
      )
      return
    end

    rights_timeline = rights_data["rights_timeline"] || []
    tenants = rights_data["tenants"] || []

    validation = Inspection::RightsValidator.call(
      base_right_date: rights_data["base_right_date"],
      tenants: tenants,
      rights_timeline: rights_timeline
    )

    report.update!(
      analyzed_at: Time.current,
      verdict: rights_data["verdict"],
      verdict_summary: rights_data["verdict_summary"],
      base_right_type: rights_data["base_right_type"],
      base_right_holder: rights_data["base_right_holder"],
      base_right_date: rights_data["base_right_date"],
      assumed_amount: validation.validated_amounts["assumed_amount"],
      total_risk_amount: validation.validated_amounts["total_risk_amount"],
      opportunity_type: rights_data["opportunity_type"],
      opportunity_reason: rights_data["opportunity_reason"],
      report_data: {
        "llm_raw" => {
          "tenants" => tenants,
          "rights_timeline" => rights_timeline,
          "reasoning" => rights_data["reasoning"],
          "checklist_references" => rights_data["checklist_references"]
        },
        "calculated" => {
          "tenants" => validation.validated_tenants,
          "assumed_amount" => validation.validated_amounts["assumed_amount"],
          "opposing_deposits" => validation.validated_amounts["opposing_deposits"],
          "total_risk_amount" => validation.validated_amounts["total_risk_amount"]
        },
        "discrepancies" => validation.discrepancies
      }
    )
  end

  def log_failure(error)
    return unless @property

    LlmAnalysisLog.create!(
      property: @property,
      user: @user,
      provider: Llm::Base.for.provider_name,
      model: Llm::Base.for.model_id,
      system_prompt: "error",
      user_prompt: "error",
      status: :failed,
      error_message: error.message,
      executed_at: Time.current
    )
  rescue => log_error
    Rails.logger.error "[PdfAnalysisService] Failed to log error: #{log_error.message}"
  end
end
