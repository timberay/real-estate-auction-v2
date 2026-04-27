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
      ProgressResult.new(steps: build_steps, current_step: nil, continue_cta: nil)
    end

    private

    def build_steps
      STEP_DEFS.map { |defn| Step.new(number: defn[:number], key: defn[:key], status: status_for(defn[:key]), detail: detail_for(defn[:key])) }
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
      simulations = EvictionSimulation.where(property_id: @user.user_properties.select(:property_id))
      return :pending unless simulations.exists?
      simulations.where(completed: true).exists? ? :done : :in_progress
    end
  end
end
