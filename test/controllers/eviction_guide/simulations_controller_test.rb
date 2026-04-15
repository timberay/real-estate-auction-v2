require "test_helper"

class EvictionGuide::SimulationsControllerTest < ActionDispatch::IntegrationTest
  test "create with property_id creates simulation and redirects to prefill" do
    property = properties(:safe_apartment)
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: { property_id: property.id }
    end
    sim = EvictionSimulation.last
    assert_equal property.id, sim.property_id
    assert_nil sim.session_id
    assert_response :redirect
    assert_redirected_to eviction_guide_simulator_prefill_path
  end

  test "prefill loads simulation from session and renders" do
    property = properties(:safe_apartment)
    # Create simulation via the create action to set session
    post eviction_guide_simulation_url, params: { property_id: property.id }
    assert_response :redirect

    get eviction_guide_simulator_prefill_path
    assert_response :success
  end

  test "create without property_id creates standalone simulation" do
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: { property_id: "" }
    end
    sim = EvictionSimulation.last
    assert_nil sim.property_id
    assert_not_nil sim.session_id
  end

  test "update records answer and redirects to next question" do
    # Create simulation via the create action to set session
    post eviction_guide_simulation_url, params: { property_id: "" }
    sim = EvictionSimulation.last

    patch eviction_guide_simulation_url, params: {
      question_code: "Q1", answer: "true", next_code: "Q2"
    }
    assert_response :redirect
    sim.reload
    assert_equal true, sim.answers["Q1"]
  end
end
