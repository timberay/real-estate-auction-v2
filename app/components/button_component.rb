# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary: "bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-400",
    secondary: "bg-slate-100 hover:bg-slate-200 text-slate-700 dark:bg-slate-700 dark:hover:bg-slate-600 dark:text-slate-200",
    outline: "border border-slate-200 hover:bg-slate-50 text-slate-700 dark:border-slate-600 dark:hover:bg-slate-700 dark:text-slate-200",
    danger: "bg-red-600 hover:bg-red-700 text-white dark:bg-red-500 dark:hover:bg-red-400",
    ghost: "hover:bg-slate-100 text-slate-600 dark:hover:bg-slate-700 dark:text-slate-300",
    link: "text-blue-600 hover:text-blue-700 underline-offset-4 hover:underline dark:text-blue-400 dark:hover:text-blue-300"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  ICON_SIZES = {
    sm: "w-4 h-4",
    md: "w-5 h-5",
    lg: "w-5 h-5"
  }.freeze

  COMMON_CLASSES = "inline-flex items-center gap-2 font-medium rounded-md transition-colors duration-150"
  FOCUS_CLASSES = "focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900"
  DISABLED_CLASSES = "opacity-50 cursor-not-allowed pointer-events-none"

  def initialize(variant: :primary, size: :md, disabled: false, icon: nil, tag: :button, href: nil, **html_options)
    @variant = variant
    @size = size
    @disabled = disabled
    @icon = icon
    @tag = tag
    @href = href
    @html_options = html_options
  end

  def call
    classes = class_names(
      COMMON_CLASSES,
      FOCUS_CLASSES,
      VARIANTS[@variant],
      SIZES[@size],
      (@disabled ? DISABLED_CLASSES : nil),
      @html_options.delete(:class)
    )

    tag_attributes = @html_options.merge(class: classes)
    tag_attributes[:disabled] = true if @disabled && @tag == :button
    tag_attributes[:href] = @href if @tag == :a

    content_tag(@tag, tag_attributes) do
      safe_join([ icon_html, content ].compact)
    end
  end

  private

  def icon_html
    return unless @icon

    raw Heroicon::Icon.render(
      name: @icon,
      variant: :outline,
      options: { class: ICON_SIZES[@size] },
      path_options: {}
    )
  end
end
