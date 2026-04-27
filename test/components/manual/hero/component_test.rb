# frozen_string_literal: true

require "test_helper"

module Manual
  module Hero
    class ComponentTest < ViewComponent::TestCase
      setup do
        @original_locale = I18n.locale
        I18n.locale = :ko
      end

      teardown { I18n.locale = @original_locale }

      def progress_fixture(current_key: :budget, cta_extra: {})
        step = Manuals::Step.new(number: 1, key: current_key, status: :pending, detail: nil)
        cta = { key: current_key, variant: :pending }.merge(cta_extra)
        Manuals::ProgressResult.new(steps: [ step ], current_step: step, continue_cta: cta)
      end

      test "renders headline, subhead, and tagline" do
        render_inline(Manual::Hero::Component.new(progress: progress_fixture))

        assert_text "경매 초보의 워크북"
        assert_text "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"
        assert_text "정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."
      end

      test "renders continue card with current step CTA" do
        render_inline(Manual::Hero::Component.new(progress: progress_fixture(current_key: :budget)))

        assert_text "이어서 하기"
        assert_selector "a[href='/onboarding']", text: "예산 설정 시작"
      end

      test "renders fallback when current_step is nil" do
        empty = Manuals::ProgressResult.new(steps: [], current_step: nil, continue_cta: nil)

        render_inline(Manual::Hero::Component.new(progress: empty))

        assert_text "처음부터 시작하기"
      end

      test "step 4 in_progress carries property_id deep link in CTA" do
        step = Manuals::Step.new(number: 4, key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })
        cta = { key: :checklist, variant: :in_progress, property_id: 7 }
        progress = Manuals::ProgressResult.new(steps: [ step ], current_step: step, continue_cta: cta)

        render_inline(Manual::Hero::Component.new(progress: progress))

        assert_selector "a[href='/properties/7']", text: "이어서 채우기 (12/26)"
      end
    end
  end
end
