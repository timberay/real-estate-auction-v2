# frozen_string_literal: true

module Manual
  module PhaseSection
    class Component < ViewComponent::Base
      def initialize(phase:, steps:, current_step_key:)
        @phase = phase
        @steps = steps
        @current_step_key = current_step_key
      end

      private

      attr_reader :phase, :steps, :current_step_key

      def heading
        t("manuals.show.phase_#{phase}.heading")
      end

      def subheading
        t("manuals.show.phase_#{phase}.subheading", count: helpers.inspection_item_total)
      end
    end
  end
end
