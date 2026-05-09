# frozen_string_literal: true

module Home
  class LandingComponent < ViewComponent::Base
    def initialize(tagline:, subtitle:, primary_cta:, secondary_cta:)
      @tagline = tagline
      @subtitle = subtitle
      @primary_cta = primary_cta
      @secondary_cta = secondary_cta
    end
  end
end
