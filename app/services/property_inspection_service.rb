class PropertyInspectionService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    begin
      AiInspectionRunner.call(property: @property, user: @user)
    rescue NotImplementedError, StandardError => e
      Rails.logger.warn("AI inspection failed: #{e.message}, falling back to rule-based")
      InspectionRunner.call(property: @property, user: @user)
    end

    RightsAnalysisService.call(property: @property, user: @user)
  end
end
