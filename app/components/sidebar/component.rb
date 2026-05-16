# frozen_string_literal: true

module Sidebar
  class Component < ViewComponent::Base
    MenuItem = Data.define(:label, :icon, :path, :enabled, :active_paths)

    MENU_GROUPS = {
      "시작하기" => [
        MenuItem.new(label: "사용자매뉴얼", icon: "book-open", path: :manual_path, enabled: true, active_paths: [])
      ],
      "물건검색" => [
        MenuItem.new(label: "예산 설정", icon: "calculator", path: :settings_budget_path, enabled: true, active_paths: [ :start_onboarding_path ]),
        MenuItem.new(label: "물건 찾기", icon: "magnifying-glass", path: :search_path, enabled: true, active_paths: []),
        MenuItem.new(label: "분석 중인 물건", icon: "folder", path: :properties_path, enabled: true, active_paths: []),
        MenuItem.new(label: "AI 분석", icon: "document-plus", path: :new_analysis_path, enabled: true, active_paths: [])
      ],
      "가이드" => [
        MenuItem.new(label: "명도 가이드", icon: "book-open", path: :eviction_guide_guide_path, enabled: true, active_paths: [])
      ]
    }.freeze

    NAV_CLASSES = "fixed left-0 top-16 bottom-0 z-30 bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 w-16 lg:w-64 hidden md:block overflow-y-auto"
    ACTIVE_CLASSES = "bg-blue-50 dark:bg-blue-900/50 text-blue-700 dark:text-blue-400 font-medium"
    ENABLED_CLASSES = "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
    DISABLED_CLASSES = "opacity-50 cursor-not-allowed text-slate-400 dark:text-slate-500"
    ITEM_COMMON_CLASSES = "flex items-center justify-center lg:justify-start lg:gap-3 lg:px-4 py-2 text-sm rounded-md transition-colors duration-150"

    def initialize(current_path: "/", current_user: nil)
      @current_path = current_path
      @current_user = current_user
    end

    private

    def resolve_path(item)
      helpers.public_send(item.path)
    end

    def active?(item)
      candidates = ([ item.path ] + item.active_paths).map { |sym| helpers.public_send(sym) }.select(&:present?)
      matched = candidates.find { |p| @current_path.start_with?(p) }
      return false unless matched

      # Prefer the longest matching path to avoid /eviction_guide matching /eviction_guide/simulator
      all_paths = MENU_GROUPS.values.flatten.flat_map { |o| [ o.path ] + o.active_paths }
      all_paths.map { |sym| helpers.public_send(sym) }.none? do |other|
        other.present? && other != matched &&
          other.length > matched.length &&
          @current_path.start_with?(other)
      end
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
