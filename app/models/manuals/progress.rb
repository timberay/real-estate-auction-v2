# frozen_string_literal: true

module Manuals
  class Progress
    STEP_DEFS = [
      { number: 1, key: :budget },
      { number: 2, key: :properties },
      { number: 3, key: :ai_analysis },
      { number: 4, key: :checklist },
      { number: 5, key: :eviction_guide },
      { number: 6, key: :simulator }
    ].freeze

    def self.for(user)
      new(user).result
    end

    def initialize(user)
      @user = user
    end

    def result
      built = build_steps
      current = pick_current_step(built)
      ProgressResult.new(steps: built, current_step: current, continue_cta: build_continue_cta(current))
    end

    private

    def build_steps
      STEP_DEFS.map { |defn| Step.new(number: defn[:number], key: defn[:key], status: status_for(defn[:key]), detail: detail_for(defn[:key])) }
    end

    def pick_current_step(built_steps)
      built_steps.find { |s| s.status != :done && s.status != :none } || built_steps.last
    end

    def build_continue_cta(step)
      base = { key: step.key, variant: cta_variant(step) }
      case step.key
      when :checklist then base.merge(property_id: latest_inspection_property_id || latest_user_property_id)
      else base
      end
    end

    def cta_variant(step)
      step.in_progress? ? :in_progress : :pending
    end

    def latest_inspection_property_id
      InspectionResult.where(user_id: @user.id, property_id: @user.user_properties.select(:property_id))
        .order(updated_at: :desc).limit(1).pick(:property_id)
    end

    def latest_user_property_id
      @user.user_properties.order(updated_at: :desc).limit(1).pick(:property_id)
    end

    def status_for(key)
      case key
      when :budget then budget_status
      when :properties then properties_status
      when :ai_analysis then ai_analysis_status
      when :checklist then checklist_status
      when :eviction_guide then :none
      when :simulator then simulator_status
      end
    end

    def detail_for(key)
      case key
      when :checklist then checklist_detail
      end
    end

    def budget_status
      budget = @user.budget_setting
      return :pending unless budget
      budget.completed? ? :done : :in_progress
    end

    def properties_status
      @user.user_properties.exists? ? :done : :pending
    end

    def ai_analysis_status
      return :pending unless @user.user_properties.exists?
      @user.user_properties.where.not(analyzed_at: nil).exists? ? :done : :in_progress
    end

    def checklist_status
      max = checklist_max_per_property
      total = checklist_total
      return :pending if max.zero?
      max >= total ? :done : :in_progress
    end

    def checklist_detail
      { done: checklist_max_per_property, total: checklist_total }
    end

    def checklist_max_per_property
      return @checklist_max_per_property if defined?(@checklist_max_per_property)

      counts = InspectionResult
        .where(user_id: @user.id, property_id: @user.user_properties.select(:property_id))
        .group(:property_id)
        .distinct
        .count(:inspection_item_id)
      @checklist_max_per_property = counts.values.max || 0
    end

    def checklist_total
      @checklist_total ||= InspectionItem.count
    end

    def simulator_status
      scope = EvictionSimulation.where(property_id: @user.user_properties.select(:property_id))
      return :done if scope.exists?(completed: true)
      scope.exists? ? :in_progress : :pending
    end
  end
end
