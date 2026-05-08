require "test_helper"

module EvictionGuide
  class SimulatorResultComponentTest < ViewComponent::TestCase
    test "renders retry CTA linking back to simulator landing" do
      simulation = EvictionSimulation.new(
        occupant_type: "junior_tenant",
        difficulty_level: "low",
        result_path: [ { "code" => "JT-S1", "name" => "권리분석", "status" => "completed" } ]
      )

      render_inline(SimulatorResultComponent.new(simulation: simulation))

      assert_selector "a[href='/eviction_guide/simulator']", text: /다시 시뮬레이션/
    end

    test "renders print CTA" do
      simulation = EvictionSimulation.new(
        occupant_type: "junior_tenant",
        difficulty_level: "low",
        result_path: []
      )

      render_inline(SimulatorResultComponent.new(simulation: simulation))

      assert_selector "button[data-action*='print']", text: /인쇄/
    end

    test "renders clarified stat labels with short descriptions" do
      simulation = EvictionSimulation.new(
        occupant_type: "junior_tenant",
        difficulty_level: "low",
        result_path: [
          { "code" => "S1", "name" => "권리분석", "status" => "completed" },
          { "code" => "B1", "name" => "협의 결렬 분기", "status" => "branch" }
        ]
      )

      render_inline(SimulatorResultComponent.new(simulation: simulation))

      assert_text "전체 명도 단계"
      assert_text "추가 분기 단계"
      refute_text "예상 총 단계"
      refute_text "분기 진입"
    end
  end
end
