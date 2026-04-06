class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @court_auction = property.raw_data&.dig("court_auction") || {}
    @registry_transcript = property.raw_data&.dig("registry_transcript") || {}
  end
end
