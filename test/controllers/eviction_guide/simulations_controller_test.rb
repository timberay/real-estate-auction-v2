require "test_helper"

class EvictionGuide::SimulationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # bootstrap a guest session (lazy guest creation)
  end

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

  test "create with property_id and occupant_type advances to first question (no prefill loop)" do
    property = properties(:safe_apartment)
    post eviction_guide_simulation_url, params: {
      property_id: property.id,
      occupant_type: "junior_tenant"
    }
    sim = EvictionSimulation.last
    assert_equal property.id, sim.property_id
    assert_equal "junior_tenant", sim.occupant_type
    assert_response :redirect
    expected_code = EvictionSimulatorQuestion.for_occupant_type("junior_tenant").ordered.first&.code || "Q1"
    assert_redirected_to eviction_guide_simulator_question_path(code: expected_code)
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

  test "update with occupant_type resets answers and progress for new simulation" do
    # Create simulation and complete it
    post eviction_guide_simulation_url, params: { property_id: "" }
    sim = EvictionSimulation.last
    sim.update!(
      occupant_type: "junior_tenant",
      answers: { "JT-Q1" => true, "JT-Q2" => true, "JT-Q3" => true },
      result_path: [ "JT-S1", "JT-S2" ],
      completed: true,
      difficulty_level: "low"
    )

    # Re-enter: select a new occupant type via update
    patch eviction_guide_simulation_url, params: { occupant_type: "debtor_owner" }
    sim.reload

    assert_equal "debtor_owner", sim.occupant_type
    assert_empty sim.answers, "answers should be reset when occupant_type changes"
    assert_empty sim.result_path, "result_path should be reset when occupant_type changes"
    assert_equal false, sim.completed, "completed should be reset when occupant_type changes"
    assert_nil sim.difficulty_level, "difficulty_level should be reset when occupant_type changes"
    assert_response :redirect
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

  test "DO-Q1 Yes advances to DO-Q2 and the page renders" do
    # E2E sweep reported clicking 네 on DO-Q1 not advancing. Lock the real
    # debtor_owner branch end-to-end so any regression in seed data or
    # rendering surfaces here.
    post eviction_guide_simulation_url, params: { property_id: "", occupant_type: "debtor_owner" }
    assert_response :redirect

    do_q1 = EvictionSimulatorQuestion.find_by!(code: "DO-Q1")
    assert_equal "DO-Q2", do_q1.yes_next_code

    patch eviction_guide_simulation_url, params: {
      question_code: "DO-Q1", answer: "true", next_code: do_q1.yes_next_code
    }
    assert_redirected_to eviction_guide_simulator_question_path(code: "DO-Q2")

    follow_redirect!
    assert_response :success
  end
end
