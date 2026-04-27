# frozen_string_literal: true

require "test_helper"

module Manual
  module FlowStrip
    class ComponentTest < ViewComponent::TestCase
      setup do
        @original_locale = I18n.locale
        I18n.locale = :ko
      end

      teardown { I18n.locale = @original_locale }

      def steps_fixture
        [
          Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil),
          Manuals::Step.new(number: 2, key: :properties, status: :in_progress, detail: nil),
          Manuals::Step.new(number: 3, key: :ai_analysis, status: :pending, detail: nil),
          Manuals::Step.new(number: 4, key: :checklist, status: :pending, detail: nil),
          Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil),
          Manuals::Step.new(number: 6, key: :simulator, status: :pending, detail: nil)
        ]
      end

      test "renders all 6 step labels" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_text "예산 정하기"
        assert_text "물건 찾기"
        assert_text "AI 분석"
        assert_text "89개 체크리스트"
        assert_text "명도 가이드"
        assert_text "명도 시뮬레이터"
      end

      test "renders auction marker between steps 4 and 5" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_text "낙찰"
      end

      test "marks current step box" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        assert_selector "[data-current-step='properties']"
      end

      test "shows status icon for all steps except :none" do
        render_inline(Manual::FlowStrip::Component.new(steps: steps_fixture, current_step_key: :properties))

        # 5 trackable steps × at least one of (✓/▶/·)
        assert_text "✓"
        assert_text "▶"
        assert_text "·"
      end
    end
  end
end
