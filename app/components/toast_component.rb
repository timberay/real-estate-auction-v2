# frozen_string_literal: true

class ToastComponent < ViewComponent::Base
  ICONS = {
    success: { name: "check-circle", color: "text-green-500" },
    warning: { name: "exclamation-triangle", color: "text-amber-500" },
    danger: { name: "x-circle", color: "text-red-500" },
    info: { name: "information-circle", color: "text-blue-500" }
  }.freeze

  CONTAINER_CLASSES = "flex items-start gap-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-lg px-4 py-3 min-w-80 max-w-md pointer-events-auto"

  def initialize(message:, type: :info, duration: 5000, action_url: nil, action_label: nil)
    @message = message
    @type = type.to_sym
    @duration = action_url ? 0 : duration
    @action_url = action_url
    @action_label = action_label
  end

  private

  def icon_config
    ICONS[@type] || ICONS[:info]
  end

  def icon_html
    raw Heroicon::Icon.render(
      name: icon_config[:name],
      variant: :outline,
      options: { class: "w-5 h-5 #{icon_config[:color]} shrink-0" },
      path_options: {}
    )
  end

  def close_icon_html
    raw Heroicon::Icon.render(
      name: "x-mark",
      variant: :outline,
      options: { class: "w-5 h-5" },
      path_options: {}
    )
  end
end
