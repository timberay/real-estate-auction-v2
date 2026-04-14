module EvictionGuide
  class DifficultyBadgeComponent < ViewComponent::Base
    VARIANTS = {
      "high" => { label: "높음", classes: "bg-red-200 text-red-800 dark:bg-red-900/30 dark:text-red-400" },
      "medium" => { label: "중간", classes: "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400" },
      "low" => { label: "낮음", classes: "bg-green-200 text-green-800 dark:bg-green-900/30 dark:text-green-400" }
    }.freeze

    def initialize(level:)
      @level = level.to_s
      @config = VARIANTS[@level] || VARIANTS["medium"]
    end

    def call
      content_tag(:span, "명도 난이도: #{@config[:label]}",
        class: "inline-flex items-center rounded-full px-4 py-1.5 text-sm font-semibold #{@config[:classes]}")
    end
  end
end
