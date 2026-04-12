# frozen_string_literal: true

module Header
  class Component < ViewComponent::Base
    HEADER_CLASSES = "fixed top-0 left-0 right-0 z-40 h-16 bg-slate-800 dark:bg-slate-900 flex items-center justify-between px-4"
    BUTTON_CLASSES = "p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"

    def initialize(app_name: "Oh My Auction", page_title: nil)
      @app_name = app_name
      @page_title = page_title.presence
    end

    private

    def hamburger_icon
      raw Heroicon::Icon.render(
        name: "bars-3",
        variant: :outline,
        options: { class: "w-6 h-6" },
        path_options: {}
      )
    end

    def sun_icon
      raw Heroicon::Icon.render(
        name: "sun",
        variant: :outline,
        options: { class: "w-5 h-5" },
        path_options: {}
      )
    end

    def moon_icon
      raw Heroicon::Icon.render(
        name: "moon",
        variant: :outline,
        options: { class: "w-5 h-5" },
        path_options: {}
      )
    end

    def bell_icon
      raw Heroicon::Icon.render(
        name: "bell",
        variant: :outline,
        options: { class: "w-5 h-5" },
        path_options: {}
      )
    end

    def user_icon
      raw Heroicon::Icon.render(
        name: "user-circle",
        variant: :outline,
        options: { class: "w-6 h-6" },
        path_options: {}
      )
    end
  end
end
