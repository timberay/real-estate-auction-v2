# frozen_string_literal: true

class LlmDataDisclosureComponent < ViewComponent::Base
  def initialize(heading_level: 3)
    @heading_level = heading_level
  end

  def heading_tag
    "h#{@heading_level}"
  end
end
