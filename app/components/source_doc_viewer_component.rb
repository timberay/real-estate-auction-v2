class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @sale_detail = property.sale_detail
    @registry_transcript = property.raw_data&.dig("registry_transcript") || {}
  end
end
