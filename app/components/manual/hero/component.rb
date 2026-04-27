# frozen_string_literal: true

module Manual
  module Hero
    class Component < ViewComponent::Base
      def initialize(progress:)
        @progress = progress
      end

      private

      attr_reader :progress

      def has_current?
        progress.current_step.present?
      end

      def cta_card_step
        progress.current_step
      end

      def cta_card_label
        return nil unless has_current?
        borrowed_step_card.send(:cta_label)
      end

      def cta_card_path
        return nil unless has_current?
        borrowed_step_card.send(:cta_path)
      end

      def borrowed_step_card
        ctx = __vc_original_view_context || @view_context
        Manual::StepCard::Component.new(step: cta_card_step, default_open: false).tap do |c|
          c.set_original_view_context(ctx)
          c.instance_variable_set(:@view_context, ctx)
        end
      end

      def fallback_path
        helpers.start_onboarding_path
      end
    end
  end
end
