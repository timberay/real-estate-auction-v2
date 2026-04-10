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
    response = Llm::Base.for.analyze(system: prompt[:system], prompt: prompt[:user])
    Inspection::InspectionResultMapper.call(
      response: response, property: @property, user: @user, items: items
    )
  end
end
