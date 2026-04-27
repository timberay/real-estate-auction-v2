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

      def cta_card_resolver
        return nil unless has_current?
        @cta_card_resolver ||= Manual::CtaResolver.new(progress.current_step)
      end

      def cta_card_label
        cta_card_resolver&.label
      end

      def cta_card_path
        cta_card_resolver&.path
      end

      def fallback_path
        helpers.start_onboarding_path
      end
    end
  end
end
