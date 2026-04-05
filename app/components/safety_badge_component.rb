# frozen_string_literal: true

class SafetyBadgeComponent < ViewComponent::Base
  RATING_CONFIG = {
    "safe" => { variant: :success, label: "Safe" },
    "caution" => { variant: :warning, label: "Caution" },
    "danger" => { variant: :danger, label: "Danger" },
    nil => { variant: :default, label: "미분석" }
  }.freeze

  def initialize(rating:)
    @config = RATING_CONFIG[rating] || RATING_CONFIG[nil]
  end

  def call
    render BadgeComponent.new(variant: @config[:variant]) do
      @config[:label]
    end
  end
end
