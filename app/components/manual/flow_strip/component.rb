# frozen_string_literal: true

module Manual
  module FlowStrip
    class Component < ViewComponent::Base
      AUCTION_MARKER_AFTER = 4

      def initialize(steps:, current_step_key:)
        @steps = steps
        @current_step_key = current_step_key
      end

      private

      attr_reader :steps, :current_step_key

      def label_for(step)
        t("manuals.steps.#{step.key}.label")
      end

      def status_icon(step)
        return nil if step.none?
        case step.status
        when :done then "✓"
        when :in_progress then "▶"
        when :pending then "·"
        end
      end

      def auction_marker
        t("manuals.show.flow_strip.auction_marker")
      end

      def current?(step)
        step.key == current_step_key
      end
    end
  end
end
