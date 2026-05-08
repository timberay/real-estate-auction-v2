# frozen_string_literal: true

module Manual
  module StepCard
    class Component < ViewComponent::Base
      def initialize(step:, default_open: false)
        @step = step
        @default_open = default_open
      end

      private

      attr_reader :step

      def open?
        @default_open
      end

      def label
        t("manuals.steps.#{step.key}.label", count: helpers.inspection_item_total)
      end

      def summary
        t("manuals.steps.#{step.key}.summary", count: helpers.inspection_item_total)
      end

      def actions
        t("manuals.steps.#{step.key}.actions", count: helpers.inspection_item_total)
      end

      def status_text
        return nil if step.none?
        t("manuals.status.#{step.status}")
      end

      def cta
        @cta ||= Manual::CtaResolver.new(step)
      end

      def screenshot_path
        "manual/0#{step.number}-#{step.key.to_s.dasherize}.png"
      end

      def screenshot_tag
        image_tag(
          screenshot_path,
          alt: label,
          class: "mt-4 rounded border border-slate-200 dark:border-slate-700",
          onerror: "this.style.display='none'"
        )
      rescue Propshaft::MissingAssetError => e
        raise unless Rails.env.local?
        Rails.logger.warn("Manual screenshot missing: #{screenshot_path} (#{e.message})")
        nil
      end
    end
  end
end
