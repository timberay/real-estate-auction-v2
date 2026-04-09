# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  VARIANTS = {
    default: "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300",
    success: "bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20 dark:bg-green-900/30 dark:text-green-400 dark:ring-green-400/20",
    warning: "bg-yellow-50 text-yellow-700 ring-1 ring-inset ring-yellow-600/20 dark:bg-yellow-900/30 dark:text-yellow-400 dark:ring-yellow-400/20",
    danger: "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20 dark:bg-red-900/30 dark:text-red-400 dark:ring-red-400/20",
    info: "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-600/20 dark:bg-blue-900/30 dark:text-blue-400 dark:ring-blue-400/20",
    accent: "bg-amber-50 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-400 dark:ring-amber-400/20"
  }.freeze

  COMMON_CLASSES = "inline-flex items-center rounded-full px-2.5 py-1 text-sm font-medium"

  def initialize(variant: :default, **html_options)
    @variant = variant
    @html_options = html_options
  end

  def call
    classes = class_names(
      COMMON_CLASSES,
      VARIANTS[@variant],
      @html_options.delete(:class)
    )

    content_tag(:span, content, **@html_options.merge(class: classes))
  end
end
