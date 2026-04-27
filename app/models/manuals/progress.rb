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
      else :pending
      end
    end

    def detail_for(_key) = nil

    def budget_status
      budget = BudgetSetting.find_by(user_id: @user.id)
      return :pending unless budget
      budget.completed_at.present? ? :done : :in_progress
    end
  end
end
