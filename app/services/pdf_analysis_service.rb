class PdfAnalysisService
  Result = Struct.new(:success?, :property, :error, keyword_init: true)

  def self.call(property: nil, documents: nil, user:)
    new(property:, documents:, user:).call
  end

  def initialize(property:, documents:, user:)
    @property = property
    @documents = documents
    @user = user
  end

  def call
    pdf_blobs = collect_documents
    return Result.new(success?: false, error: "문서를 먼저 업로드해주세요.") if pdf_blobs.empty?

    items = InspectionItem.ordered
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

    log_analysis(property, llm, prompts, response)

    UserProperty.find_or_create_by!(user: @user, property: property)
    InspectionRatingService.call(property: property, user: @user)

    Result.new(success?: true, property: property)
  rescue => e
    log_failure(e)
    raise
  end

  private

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
    return @property if @property

    case_number = metadata&.dig("case_number")
    property = Property.find_by(case_number: case_number) if case_number.present?

    property || Property.create!(
      case_number: case_number || "PDF-#{SecureRandom.hex(4)}",
      address: metadata&.dig("address"),
      property_type: metadata&.dig("property_type"),
      appraisal_price: metadata&.dig("appraisal_price"),
      min_bid_price: metadata&.dig("min_bid_price")
    )
  end

  def attach_documents_to_property(property, blobs)
    blobs.each do |blob|
      property.documents.attach(blob) unless property.documents.blobs.include?(blob)
    end
  end

  def log_analysis(property, llm, prompts, response)
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
