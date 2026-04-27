# frozen_string_literal: true

module Manual
  class Component < ViewComponent::Base
    def initialize(progress:)
      @progress = progress
    end

    private

    attr_reader :progress

    def pre_auction_steps
      progress.steps.first(4)
    end

    def post_auction_steps
      progress.steps.last(2)
    end

    def current_step_key
      progress.current_step&.key
    end
  end
end
