# frozen_string_literal: true

module Sidebar
  class Component < ViewComponent::Base
    MenuItem = Data.define(:label, :icon, :path, :enabled)

    MENU_GROUPS = {
      "물건검색" => [
        MenuItem.new(label: "예산 설정", icon: "calculator", path: "/onboarding", enabled: true),
        MenuItem.new(label: "물건 목록", icon: "magnifying-glass", path: "/properties", enabled: true),
        MenuItem.new(label: "AI분석", icon: "document-plus", path: "/analyses/new", enabled: true)
      ],
      "리포트" => [
        MenuItem.new(label: "순수익 계산기", icon: "banknotes", path: nil, enabled: false),
        MenuItem.new(label: "리포트 내보내기", icon: "arrow-down-tray", path: nil, enabled: false)
      ],
      "가이드" => [
        MenuItem.new(label: "명도 가이드", icon: "book-open", path: "/eviction_guide", enabled: true),
        MenuItem.new(label: "명도 시뮬레이터", icon: "play-circle", path: "/eviction_guide/simulator", enabled: true)
      ]
    }.freeze

    NAV_CLASSES = "fixed left-0 top-16 bottom-0 z-30 bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 w-16 lg:w-64 hidden md:block overflow-y-auto"
    ACTIVE_CLASSES = "bg-blue-50 dark:bg-blue-900/50 text-blue-700 dark:text-blue-400 font-medium"
    ENABLED_CLASSES = "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
    DISABLED_CLASSES = "opacity-50 cursor-not-allowed text-slate-400 dark:text-slate-500"
    ITEM_COMMON_CLASSES = "flex items-center justify-center lg:justify-start lg:gap-3 lg:px-4 py-2 text-sm rounded-md transition-colors duration-150"

    def initialize(current_path: "/")
      @current_path = current_path
    end

    private

    def active?(item)
      item.path.present? && @current_path.start_with?(item.path)
    end

    def item_classes(item)
      base = ITEM_COMMON_CLASSES
      if active?(item)
        "#{base} #{ACTIVE_CLASSES}"
      elsif item.enabled
        "#{base} #{ENABLED_CLASSES}"
      else
        "#{base} #{DISABLED_CLASSES}"
      end
    end

    def menu_icon(name)
      raw Heroicon::Icon.render(
        name: name,
        variant: :outline,
        options: { class: "w-5 h-5 flex-shrink-0" },
        path_options: {}
      )
    end

    def toggle_icon
      raw Heroicon::Icon.render(
        name: "chevron-double-left",
        variant: :outline,
        options: { class: "w-5 h-5" },
        path_options: {}
      )
    end
  end
end
