# frozen_string_literal: true

require "test_helper"

module Manual
  class ComponentTest < ViewComponent::TestCase
    setup do
      @original_locale = I18n.locale
      I18n.locale = :ko
    end

    teardown { I18n.locale = @original_locale }

    def progress_fixture
      steps = [
        Manuals::Step.new(number: 1, key: :budget, status: :done, detail: nil),
        Manuals::Step.new(number: 2, key: :properties, status: :in_progress, detail: nil),
        Manuals::Step.new(number: 3, key: :ai_analysis, status: :pending, detail: nil),
        Manuals::Step.new(number: 4, key: :checklist, status: :pending, detail: nil),
        Manuals::Step.new(number: 5, key: :eviction_guide, status: :none, detail: nil),
        Manuals::Step.new(number: 6, key: :simulator, status: :pending, detail: nil)
      ]
      Manuals::ProgressResult.new(steps: steps, current_step: steps[1], continue_cta: { key: :properties, variant: :pending })
    end

    test "renders hero, flow strip, both phase sections, footer" do
      render_inline(Manual::Component.new(progress: progress_fixture))

      assert_text "경매 초보의 워크북"      # hero
      assert_text "낙찰"                    # flow strip auction marker
      assert_text "낙찰 전"                 # pre-auction heading
      assert_text "낙찰 후"                 # post-auction heading
      assert_text "각 화면에서 막히면"      # footer
    end

    test "splits steps 1-4 into pre and 5-6 into post" do
      render_inline(Manual::Component.new(progress: progress_fixture))

      # 4 step cards in pre + 2 in post = 6 total
      assert_selector "details", count: 6
    end
  end
end
