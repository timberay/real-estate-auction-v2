module EvictionGuide
  class LegalInlineComponent < ViewComponent::Base
    def initialize(legal_items:)
      items = legal_items || []
      @legal_items = items.is_a?(String) ? JSON.parse(items) : items
    end
  end
end
