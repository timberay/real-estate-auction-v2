# frozen_string_literal: true

class WizardStepComponent < ViewComponent::Base
  STEP_LABELS = {
    1 => "유용자금",
    2 => "예비비",
    3 => "대출 설정"
  }.freeze

  def initialize(title:, current_step:, total_steps:, description: nil)
    @title = title
    @current_step = current_step
    @total_steps = total_steps
    @description = description
  end

  private

  def step_label(step)
    STEP_LABELS[step] || "Step #{step}"
  end

  def circle_classes(step)
    base = "w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold shrink-0"
    if step < @current_step
      "#{base} bg-blue-600 text-white dark:bg-blue-500"
    elsif step == @current_step
      "#{base} bg-blue-600 text-white ring-4 ring-blue-600/20 dark:bg-blue-500 dark:ring-blue-500/20"
    else
      "#{base} bg-slate-200 text-slate-500 dark:bg-slate-700 dark:text-slate-400"
    end
  end

  def label_classes(step)
    if step <= @current_step
      "text-sm font-medium text-slate-900 dark:text-slate-100"
    else
      "text-sm font-medium text-slate-400 dark:text-slate-500"
    end
  end

  def line_classes(step)
    base = "flex-1 h-0.5"
    if step < @current_step
      "#{base} bg-blue-600 dark:bg-blue-500"
    else
      "#{base} bg-slate-200 dark:bg-slate-700"
    end
  end
end
