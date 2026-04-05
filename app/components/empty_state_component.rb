# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(icon:, title:, description:, cta_text: nil, cta_href: nil)
    @icon = icon
    @title = title
    @description = description
    @cta_text = cta_text
    @cta_href = cta_href
  end

  private

  def icon_html
    raw Heroicon::Icon.render(
      name: @icon,
      variant: :outline,
      options: { class: "w-12 h-12 text-slate-300 dark:text-slate-600 mb-4" },
      path_options: {}
    )
  end

  def cta?
    @cta_text.present? && @cta_href.present?
  end
end
