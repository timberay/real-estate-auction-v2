# frozen_string_literal: true

require "test_helper"

module Manual
  module StepCard
    class ComponentTest < ViewComponent::TestCase
      setup do
        @original_locale = I18n.locale
        I18n.locale = :ko
      end

      teardown { I18n.locale = @original_locale }

      test "renders label and summary from i18n" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_text "예산 정하기"
        assert_text "내가 살 수 있는 가격대를 먼저 못 박습니다."
      end

      test "is collapsed when default_open is false" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_no_selector "details[open]"
        assert_selector "details"
      end

      test "is open when default_open is true" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_selector "details[open]"
      end

      test "renders status icon for trackable step" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_text "✓ 완료"
      end

      test "omits status icon for :none status (eviction guide)" do
        step = Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: false))

        assert_no_text "완료"
        assert_no_text "진행 중"
        assert_no_text "미시작"
      end

      test "checklist in_progress CTA shows progress count" do
        step = Manuals::Step.new(number: 4, key: :checklist, status: :in_progress, detail: { done: 12, total: 26 })

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_text "이어서 채우기 (12/26)"
      end

      test "renders actions list from i18n" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_text "보유 현금과 대출 한도 입력"
        assert_text "취득세·수리비·이사비 등 부대비용 자동 계산"
        assert_text "지역과 평형대 설정"
      end

      test "CTA links to the right path per step key" do
        step = Manuals::Step.new(number: 2, key: :properties, status: :pending, detail: nil)

        render_inline(Manual::StepCard::Component.new(step: step, default_open: true))

        assert_selector "a[href='/properties']"
      end

      test "missing screenshot does not raise — silently swallowed in dev/test" do
        step = Manuals::Step.new(number: 1, key: :budget, status: :pending, detail: nil)

        # Default test env, asset truly does not exist (placeholders added in Task 19).
        # Should not raise; should log a warning.
        assert_nothing_raised do
          render_inline(Manual::StepCard::Component.new(step: step, default_open: true))
        end
      end
    end
  end
end
