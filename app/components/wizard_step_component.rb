# frozen_string_literal: true

class WizardStepComponent < ViewComponent::Base
  def initialize(title:, current_step:, total_steps:, description: nil)
    @title = title
    @current_step = current_step
    @total_steps = total_steps
    @description = description
  end

  private

  def dot_class(step)
    base = "w-3 h-3 rounded-full"
    if step == @current_step
      "#{base} bg-blue-600 ring-4 ring-blue-600/20"
    elsif step < @current_step
      "#{base} bg-blue-600"
    else
      "#{base} bg-slate-200 dark:bg-slate-600"
    end
  end

  def line_class(step)
    base = "w-8 h-0.5"
    if step < @current_step
      "#{base} bg-blue-600"
    else
      "#{base} bg-slate-200 dark:bg-slate-600"
    end
  end
end
