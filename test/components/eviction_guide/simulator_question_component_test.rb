require "test_helper"

module EvictionGuide
  class SimulatorQuestionComponentTest < ViewComponent::TestCase
    setup do
      @main_question = eviction_simulator_questions(:jt_q1_dividend)
      @simulation = eviction_simulations(:junior_tenant_sim)
      @step = eviction_steps(:jt_s1_dividend_check)
    end

    test "renders main flow progress bar for a main question" do
      render_inline(SimulatorQuestionComponent.new(
        question: @main_question,
        simulation: @simulation,
        step: @step
      ))

      assert_selector "[data-test='main-progress']"
      assert_no_selector "[data-test='branch-indicator']"
    end

    test "renders branch indicator instead of main progress for a branch question" do
      branch_question = EvictionSimulatorQuestion.new(
        code: "JT-Q1G",
        phase: "summary",
        step_code: @step.code,
        question: "분기 질문",
        occupant_type: "junior_tenant"
      )

      render_inline(SimulatorQuestionComponent.new(
        question: branch_question,
        simulation: @simulation,
        step: @step
      ))

      assert_selector "[data-test='branch-indicator']"
      assert_text "추가 확인 — 답에 따라 절차가 달라져요"
      assert_no_text "분기 경로 진입"
      assert_no_text "리스크 확인 질문"
      assert_no_selector "[data-test='main-progress']"
    end

    test "step badge omits internal step code, shows only the user-facing step name (C5)" do
      render_inline(SimulatorQuestionComponent.new(
        question: @main_question,
        simulation: @simulation,
        step: @step
      ))

      # C5: step codes like "JT-S1" are internal — surface only the human
      # name. The component used to render "JT-S1 — 배당표 확인" which leaks
      # the code.
      assert_no_text @step.code
      assert_text(@step.name)
    end

    test "yes/no buttons stack vertically on mobile, horizontally on sm and up (C3)" do
      render_inline(SimulatorQuestionComponent.new(
        question: @main_question,
        simulation: @simulation,
        step: @step
      ))

      # The yes/no button row wraps the two forms inside a flex container.
      # On mobile (< sm) it must stack vertically so the buttons don't squeeze;
      # at sm and up it switches to a horizontal row.
      yes_form = page.find("form[action*='eviction_guide']", match: :first)
      wrapper = yes_form.find(:xpath, "..")
      assert_includes wrapper[:class], "flex-col",
        "expected yes/no wrapper to stack vertically on mobile"
      assert_includes wrapper[:class], "sm:flex-row",
        "expected yes/no wrapper to switch to row on sm and up"
    end
  end
end
