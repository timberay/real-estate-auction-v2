# frozen_string_literal: true

module Onboarding
  class HelpTooltipComponent < ViewComponent::Base
    def initialize(text:)
      @text = text
    end
  end
end
