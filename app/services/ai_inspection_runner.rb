class AiInspectionRunner
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    text = Inspection::PropertyDataAssembler.call(@property)
    items = InspectionItem.ordered
    prompt = Inspection::InspectionPromptBuilder.call(property_text: text, items: items)
    adapter = Llm::Base.for

    log = create_log(prompt, adapter)

    begin
      response = adapter.analyze(system: prompt[:system], prompt: prompt[:user])
      complete_log(log, response)
      Inspection::InspectionResultMapper.call(
        response: response, property: @property, user: @user, items: items
      )
    rescue => e
      fail_log(log, e)
      raise
    end
  end

  private

  def create_log(prompt, adapter)
    LlmAnalysisLog.create!(
      property: @property,
      user: @user,
      system_prompt: prompt[:system],
      user_prompt: prompt[:user],
      provider: adapter.provider_name,
      model: adapter.model_id,
      status: :pending
    )
  end

  def complete_log(log, response)
    log.update!(
      status: :completed,
      response_json: response,
      executed_at: Time.current
    )
  end

  def fail_log(log, error)
    log.update!(
      status: :failed,
      error_message: error.message,
      executed_at: Time.current
    )
  end
end
