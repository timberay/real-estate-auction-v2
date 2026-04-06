class PropertyAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = AutoCheckRunner.call(property: @property, user: @user)
    pending = results.select { |r| r.source_type.nil? }

    { results: results, pending_manual_items: pending }
  end
end
