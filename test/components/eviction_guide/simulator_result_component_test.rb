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
  end
end
