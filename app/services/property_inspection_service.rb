class PropertyInspectionService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    InspectionRunner.call(property: @property, user: @user)
    RightsAnalysisService.call(property: @property, user: @user)
  end
end
