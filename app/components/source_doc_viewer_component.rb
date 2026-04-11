class SourceDocViewerComponent < ViewComponent::Base
  def initialize(property:)
    @property = property
    @sale_detail = nil
    @registry_transcript = {}
  end
end
