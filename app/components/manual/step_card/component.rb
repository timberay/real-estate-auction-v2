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
        t("manuals.steps.#{step.key}.label")
      end

      def summary
        t("manuals.steps.#{step.key}.summary")
      end

      def actions
        t("manuals.steps.#{step.key}.actions")
      end

      def status_text
        return nil if step.none?
        t("manuals.status.#{step.status}")
      end

      def cta_label
        if step.in_progress? && step.key == :checklist && step.detail
          t("manuals.cta.checklist.in_progress", done: step.detail[:done], total: step.detail[:total])
        elsif step.in_progress?
          t("manuals.cta.#{step.key}.in_progress", default: t("manuals.cta.#{step.key}.default"))
        else
          t("manuals.cta.#{step.key}.default")
        end
      end

      def cta_path
        case step.key
        when :budget then helpers.start_onboarding_path
        when :properties then helpers.properties_path
        when :ai_analysis then helpers.new_analysis_path
        when :checklist then helpers.properties_path
        when :eviction_guide then helpers.eviction_guide_guide_path
        when :simulator then helpers.eviction_guide_simulator_path
        end
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
