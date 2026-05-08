module EvictionGuide
  class DifficultyBreakdownComponent < ViewComponent::Base
    BASE_REASONS = {
      "junior_tenant" => {
        label: "후순위 임차인",
        reason: "배당으로 보증금을 회수하므로 명도확인서 협상이 가능하고 인도명령 절차도 표준입니다."
      },
      "debtor_owner" => {
        label: "채무자 본인",
        reason: "인도명령 대상이 명확하지만, 자진 퇴거 협상과 강제집행 단계가 남아 있어 1~3개월 소요됩니다."
      },
      "senior_tenant" => {
        label: "선순위 임차인",
        reason: "보증금 인수 부담이 있고, 협상이 결렬되면 명도소송으로 6~12개월 추가됩니다."
      },
      "illegal_occupant" => {
        label: "불법 점유자",
        reason: "인도명령이 불가능해 명도소송(6~12개월)으로만 진행 가능합니다."
      }
    }.freeze

    LEVEL_LABELS = { "high" => "높음", "medium" => "중간", "low" => "낮음" }.freeze
    LEVEL_RANK = { "high" => 3, "medium" => 2, "low" => 1 }.freeze

    IMPACT_BADGE_CLASSES = {
      "high"   => "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
      "medium" => "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300",
      "low"    => "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
    }.freeze

    def initialize(breakdown:)
      @breakdown = breakdown
    end

    private

    def base_label
      info = BASE_REASONS[@breakdown.base[:occupant_type]]
      info ? info[:label] : nil
    end

    def base_reason
      info = BASE_REASONS[@breakdown.base[:occupant_type]]
      info ? info[:reason] : "점유자 유형이 지정되지 않아 평균적인 난이도로 평가되었습니다."
    end

    def base_level_label
      LEVEL_LABELS[@breakdown.base[:level]] || "—"
    end

    def triggers
      @breakdown.triggers
    end

    def triggers_present?
      triggers.any?
    end

    def triggers_count
      triggers.size
    end

    def highest_trigger_impact_label
      ranked = triggers.map { |t| t[:impact] }.max_by { |i| LEVEL_RANK[i] || 0 }
      LEVEL_LABELS[ranked] || "—"
    end

    def impact_badge_classes(impact)
      IMPACT_BADGE_CLASSES[impact] || IMPACT_BADGE_CLASSES["medium"]
    end

    def impact_label(impact)
      LEVEL_LABELS[impact] || impact.to_s
    end
  end
end
