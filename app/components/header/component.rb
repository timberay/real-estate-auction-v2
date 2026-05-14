# frozen_string_literal: true

module Header
  class Component < ViewComponent::Base
    HEADER_CLASSES = "fixed top-0 left-0 right-0 z-40 h-16 bg-slate-800 dark:bg-slate-900 flex items-center justify-between px-4 md:px-6"
    BUTTON_CLASSES = "p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"

    def initialize(app_name: "부동산 경매 도우미", page_title: nil, current_user: nil)
      @app_name = app_name
      @page_title = page_title.presence
      @current_user = current_user
    end

    private

    def signed_in?
      @current_user && !@current_user.guest?
    end

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

    def unread_notification_count
      @current_user&.notifications&.unread&.count.to_i
    end
  end
end
