module EvictionGuide
  class LegalInlineComponent < ViewComponent::Base
    def initialize(legal_items:)
      @legal_items = legal_items || []
    end
  end
end
