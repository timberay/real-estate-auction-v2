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
  rescue JSON::ParserError => e
    write_extraction_failure(reason: "응답 JSON 파싱 실패: #{e.message.to_s.truncate(120)}")
    log_failure(e)
    raise
  rescue Faraday::TimeoutError => e
    write_extraction_failure(reason: "AI 서버 응답 시간 초과")
    log_failure(e)
    raise
  rescue => e
    write_extraction_failure(reason: "분석 중 알 수 없는 오류 (#{e.class.name})")
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

  # Strip only ASCII space (U+0020) — matches the REPLACE(' ', '') used in SQL queries,
  # so Ruby comparison and DB lookup behave identically for Korean court case numbers.
  def normalize_case(s)
    s.to_s.gsub(" ", "").downcase
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
        report_data: {
          "analysis_status" => "extraction_failed",
          "failed_at" => Time.current.iso8601,
          "failure_reason" => "AI 응답에서 rights_analysis 필드를 찾지 못했습니다."
        }
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

    opportunity_type, opportunity_evidence = enforce_hug_waiver_citation(rights_data, property)

    report.update!(
      analyzed_at: Time.current,
      verdict: rights_data["verdict"],
      verdict_summary: rights_data["verdict_summary"],
      base_right_type: rights_data["base_right_type"],
      base_right_holder: rights_data["base_right_holder"],
      base_right_date: rights_data["base_right_date"],
      assumed_amount: validation.validated_amounts["assumed_amount"],
      total_risk_amount: validation.validated_amounts["total_risk_amount"],
      opportunity_type: opportunity_type,
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
          "total_risk_amount" => validation.validated_amounts["total_risk_amount"],
          "unevaluated_rights" => validation.validated_amounts["unevaluated_rights"],
          "disclaimer" => validation.validated_amounts["disclaimer"]
        },
        "opportunity_evidence" => opportunity_evidence,
        "discrepancies" => validation.discrepancies
      }
    )
  end

  # B5 / E-11: Persist a human-readable failure_reason on the report so the UI
  # can surface "왜 실패했는지" + a retry button. Guarded: does nothing when
  # @property is nil (case_number-first flow where the property has not
  # been resolved yet — there's no report to attach to).
  def write_extraction_failure(reason:)
    return unless @property

    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: @property)
    report.update!(
      analyzed_at: Time.current,
      verdict_summary: nil,
      report_data: {
        "analysis_status" => "extraction_failed",
        "failed_at" => Time.current.iso8601,
        "failure_reason" => reason
      }
    )
  rescue => e
    Rails.logger.error "[PdfAnalysisService] Failed to write extraction failure: #{e.message}"
  end

  # B8 / E-41: hug_waiver requires explicit citation evidence (source_doc + page_number + quote).
  # If LLM returns hug_waiver without all three, null the opportunity_type defensively.
  # Other opportunity_type values are unaffected.
  def enforce_hug_waiver_citation(rights_data, property)
    raw_type = rights_data["opportunity_type"]
    source_doc = rights_data["opportunity_source_doc"].presence
    page_number = rights_data["opportunity_page_number"]
    quote = rights_data["opportunity_quote"].presence

    evidence = {
      "source_doc" => source_doc,
      "page_number" => page_number,
      "quote" => quote
    }

    if raw_type == "hug_waiver" && (source_doc.blank? || page_number.blank? || quote.blank?)
      Rails.logger.warn(
        "[PdfAnalysisService] LLM returned hug_waiver without complete citation; " \
        "opportunity_type nulled for property=#{property.id}"
      )
      [ nil, evidence ]
    else
      [ raw_type, evidence ]
    end
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
