# frozen_string_literal: true

require "test_helper"

module Manual
  module PhaseSection
    class ComponentTest < ViewComponent::TestCase
      setup do
        @original_locale = I18n.locale
        I18n.locale = :ko
      end

      teardown { I18n.locale = @original_locale }

      def fixture_steps
        (1..6).map { |n| Manuals::Step.new(number: n, key: :budget, status: :pending, detail: nil) }
      end

      test "renders pre-auction heading and step cards" do
        steps = fixture_steps.first(4)

        render_inline(Manual::PhaseSection::Component.new(phase: :pre, steps: steps, current_step_key: :budget))

        assert_text "낙찰 전"
        assert_text "#{InspectionItem.count}개 체크리스트로 직접 분석합니다"
      end

      test "renders post-auction heading and step cards" do
        steps = fixture_steps.last(2)

        render_inline(Manual::PhaseSection::Component.new(phase: :post, steps: steps, current_step_key: :simulator))

        assert_text "낙찰 후"
        assert_text "명도 시뮬레이터로 다음 한 수를 정합니다"
      end

      test "opens only the current step card by default" do
        budget_done = Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil)
        properties_pending = Manuals::Step.new(number: 2, key: :properties, status: :pending, detail: nil)

        render_inline(Manual::PhaseSection::Component.new(phase: :pre, steps: [ budget_done, properties_pending ], current_step_key: :properties))

        # Only one <details open> in output
        assert_selector "details[open]", count: 1
      end
    end
  end
end
