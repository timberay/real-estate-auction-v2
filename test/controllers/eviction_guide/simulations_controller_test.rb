require "test_helper"

class EvictionGuide::SimulationsControllerTest < ActionDispatch::IntegrationTest
  test "create with property_id creates persisted simulation" do
    property = properties(:safe_apartment)
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: {
        simulation: { property_id: property.id }
      }
    end
    sim = EvictionSimulation.last
    assert_equal property.id, sim.property_id
    assert_nil sim.session_id
  end

  test "create without property_id creates standalone simulation" do
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: {
        simulation: { property_id: "" }
      }
    end
    sim = EvictionSimulation.last
    assert_nil sim.property_id
    assert_not_nil sim.session_id
  end

  test "update records answer and redirects to next question" do
    # Create simulation via the create action to set session
    property = properties(:risky_villa)
    post eviction_guide_simulation_url, params: {
      simulation: { property_id: property.id }
    }
    sim = EvictionSimulation.last

    patch eviction_guide_simulation_url, params: {
      simulation: { question_code: "Q1", answer: "true", next_code: "Q2" }
    }
    assert_response :redirect
    sim.reload
    assert_equal true, sim.answers["Q1"]
  end
end
