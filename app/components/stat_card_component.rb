# frozen_string_literal: true

class StatCardComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-blue-600 dark:bg-blue-700 text-white rounded-xl p-6 text-center",
    muted: "bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4"
  }.freeze

  def initialize(label:, value:, sublabel: nil, variant: :primary)
    @label = label
    @value = value
    @sublabel = sublabel
    @variant = variant.to_sym
  end

  private

  def container_classes
    VARIANTS[@variant]
  end

  def label_classes
    if @variant == :primary
      "text-sm opacity-80"
    else
      "text-sm text-slate-500 dark:text-slate-400"
    end
  end

  def value_classes
    if @variant == :primary
      "text-3xl font-bold tabular-nums"
    else
      "text-2xl font-bold text-slate-900 dark:text-slate-100 tabular-nums"
    end
  end

  def sublabel_classes
    if @variant == :primary
      "text-xs opacity-70 mt-1"
    else
      "text-xs text-slate-400 dark:text-slate-500 mt-1"
    end
  end
end
