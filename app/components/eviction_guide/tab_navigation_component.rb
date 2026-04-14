module EvictionGuide
  class TabNavigationComponent < ViewComponent::Base
    TAB_CONFIG = [
      { key: "guide",     label: "명도 가이드",     path_method: :eviction_guide_guide_path },
      { key: "simulator", label: "명도 시뮬레이터", path_method: :eviction_guide_simulator_path }
    ].freeze

    def initialize(active_tab:)
      @active_tab = active_tab
    end

    private

    def tabs
      TAB_CONFIG.map do |tab|
        tab.merge(
          active: tab[:key] == @active_tab,
          url: helpers.send(tab[:path_method])
        )
      end
    end
  end
end
