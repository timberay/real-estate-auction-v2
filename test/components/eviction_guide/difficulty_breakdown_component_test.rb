require "test_helper"

module EvictionGuide
  class DifficultyBreakdownComponentTest < ViewComponent::TestCase
    Result = EvictionGuide::DifficultyAssessor::Result

    def build_breakdown(level: "low", base_level: "low", occupant_type: "junior_tenant", triggers: [])
      Result.new(
        level: level,
        base: { level: base_level, occupant_type: occupant_type },
        triggers: triggers
      )
    end

    test "renders junior_tenant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "junior_tenant")
      ))

      assert_text "기본 난이도"
      assert_text "후순위 임차인"
      assert_text "배당으로 보증금을 회수"
    end

    test "renders debtor_owner base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "debtor_owner", base_level: "medium")
      ))

      assert_text "채무자"
      assert_text "1~3개월 소요"
    end

    test "renders senior_tenant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "senior_tenant", base_level: "high", level: "high")
      ))

      assert_text "선순위 임차인"
      assert_text "보증금 인수 부담"
    end

    test "renders illegal_occupant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "illegal_occupant", base_level: "high", level: "high")
      ))

      assert_text "불법 점유자"
      assert_text "명도소송"
    end

    test "renders fallback when occupant_type is nil" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: nil, base_level: nil)
      ))

      assert_text "점유자 유형이 지정되지 않아"
    end

    test "shows '추가 위험 요인 없음' when triggers empty" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(triggers: [])
      ))

      assert_text "추가 위험 요인"
      assert_text "없음"
      assert_text "기본 난이도가 그대로 유지"
    end

    test "lists triggers with step name, impact, help_text when present" do
      triggers = [
        { code: "Q5", step_code: "S5",
          step_name: "인도명령 + 점유이전금지가처분 동시 신청",
          impact: "high",
          help_text: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다." }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "S5 인도명령 + 점유이전금지가처분 동시 신청"
      assert_text "+높음"
      assert_text "잔금 납부일 당일"
    end

    test "trigger header shows count and highest impact" do
      triggers = [
        { code: "Q5", step_code: "S5", step_name: "인도명령", impact: "high", help_text: "..." },
        { code: "Q14", step_code: "S14", step_name: "관리비", impact: "medium", help_text: "..." }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "추가 위험 요인"
      assert_text "2건"
      assert_text "영향도: 높음"
    end

    test "does NOT show question codes (Q5G etc) only step labels" do
      triggers = [
        { code: "Q5G", step_code: "S5", step_name: "인도명령 신청",
          impact: "high", help_text: "도움말" }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      refute_text "Q5G"
    end

    test "renders closing rule note even when triggers exist" do
      triggers = [
        { code: "Q5", step_code: "S5", step_name: "인도명령",
          impact: "high", help_text: "도움말" }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도"
    end

    test "renders closing rule note when triggers empty" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(triggers: [])
      ))

      assert_text "기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도"
    end
  end
end
