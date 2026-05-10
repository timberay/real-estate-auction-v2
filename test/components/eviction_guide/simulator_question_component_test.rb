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
  end
end
