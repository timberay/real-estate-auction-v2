class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @sale_detail = nil
    @registry_transcript = property.raw_data&.dig("registry_transcript") || {}
  end
end
