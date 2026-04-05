# frozen_string_literal: true

module Sidebar
  class Component < ViewComponent::Base
    MenuItem = Data.define(:label, :icon, :path, :enabled)

    MENU_GROUPS = {
      "물건검색" => [
        MenuItem.new(label: "예산 설정", icon: "calculator", path: "/onboarding", enabled: true),
        MenuItem.new(label: "물건 목록", icon: "magnifying-glass", path: "/properties", enabled: true),
        MenuItem.new(label: "시세 조회", icon: "chart-bar", path: nil, enabled: false)
      ],
      "권리분석" => [
        MenuItem.new(label: "권리분석 리포트", icon: "document-magnifying-glass", path: nil, enabled: false),
        MenuItem.new(label: "수익 계산기", icon: "banknotes", path: nil, enabled: false),
        MenuItem.new(label: "대출 매칭", icon: "building-library", path: nil, enabled: false)
      ],
      "입찰" => [
        MenuItem.new(label: "진행 체크리스트", icon: "clipboard-document-check", path: nil, enabled: false),
        MenuItem.new(label: "가상 입찰", icon: "play-circle", path: nil, enabled: false),
        MenuItem.new(label: "사전 임장", icon: "map-pin", path: nil, enabled: false)
      ],
      "낙찰" => [
        MenuItem.new(label: "명도 가이드", icon: "key", path: nil, enabled: false),
        MenuItem.new(label: "전문가 연결", icon: "user-group", path: nil, enabled: false)
      ]
    }.freeze

    NAV_CLASSES = "fixed left-0 top-16 bottom-0 z-30 bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 w-64 hidden md:block overflow-y-auto"
    ACTIVE_CLASSES = "bg-blue-50 dark:bg-blue-900/50 text-blue-700 dark:text-blue-400 font-medium"
    ENABLED_CLASSES = "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
    DISABLED_CLASSES = "opacity-50 cursor-not-allowed text-slate-400 dark:text-slate-500"
    ITEM_COMMON_CLASSES = "flex items-center gap-3 px-4 py-2 text-sm rounded-md transition-colors duration-150"

    def initialize(current_path: "/")
      @current_path = current_path
    end

    private

    def active?(item)
      item.path.present? && item.path == @current_path
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

    def chevron_icon
      raw Heroicon::Icon.render(
        name: "chevron-down",
        variant: :outline,
        options: { class: "w-4 h-4 transition-transform duration-200" },
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
