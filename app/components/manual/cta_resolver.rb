# frozen_string_literal: true

module Manual
  class CtaResolver
    PATH_HELPERS = {
      budget: :start_onboarding_path,
      properties: :properties_path,
      ai_analysis: :new_analysis_path,
      checklist: :properties_path,
      eviction_guide: :eviction_guide_guide_path,
      simulator: :eviction_guide_simulator_path
    }.freeze

    def initialize(step, property_id: nil)
      @step = step
      @property_id = property_id
    end

    def path
      if @step.key == :checklist && @property_id
        Rails.application.routes.url_helpers.property_path(@property_id)
      else
        Rails.application.routes.url_helpers.public_send(PATH_HELPERS.fetch(@step.key))
      end
    end

    def label
      if checklist_in_progress_with_detail?
        I18n.t("manuals.cta.checklist.in_progress",
               done: @step.detail[:done],
               total: @step.detail[:total])
      elsif @step.in_progress? && @step.key != :checklist
        I18n.t("manuals.cta.#{@step.key}.in_progress",
               default: I18n.t("manuals.cta.#{@step.key}.default"))
      else
        I18n.t("manuals.cta.#{@step.key}.default")
      end
    end

    # Pass count: explicitly to share request-scoped memoization.
    def step_label(count: nil)
      I18n.t("manuals.steps.#{@step.key}.label", count: count || InspectionItem.count)
    end

    private

    def checklist_in_progress_with_detail?
      @step.in_progress? && @step.key == :checklist && @step.detail
    end
  end
end
