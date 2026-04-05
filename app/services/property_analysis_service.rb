class PropertyAnalysisService
  def self.call(property:)
    new(property:).call
  end

  def initialize(property:)
    @property = property
  end

  def call
    results = AutoCheckRunner.call(property: @property)
    pending = results.select { |r| r.source_type.nil? }

    { results: results, pending_manual_items: pending }
  end
end
