class PropertyAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    AutoCheckRunner.call(property: @property, user: @user)
  end
end
