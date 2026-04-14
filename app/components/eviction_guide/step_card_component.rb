module EvictionGuide
  class StepCardComponent < ViewComponent::Base
    def initialize(step:, branches: [])
      @step = step
      @branches = branches
    end

    private

    def step_badge_classes
      if @step.main?
        "bg-blue-600 text-white dark:bg-blue-500"
      else
        "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300"
      end
    end

    def has_branches?
      @branches.any?
    end
  end
end
