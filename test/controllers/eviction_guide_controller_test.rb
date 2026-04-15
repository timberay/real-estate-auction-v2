require "test_helper"

class EvictionGuideControllerTest < ActionDispatch::IntegrationTest
  setup do
    eviction_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_steps.json")))
    (eviction_data["steps"] + eviction_data["branches"]).each do |attrs|
      EvictionStep.find_or_create_by!(code: attrs["code"]) do |step|
        attrs.each { |k, v| step.send(:"#{k}=", v) if step.respond_to?(:"#{k}=") }
      end
    end

    questions_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_simulator_questions.json")))
    questions_data.each do |attrs|
      EvictionSimulatorQuestion.find_or_create_by!(code: attrs["code"]) do |q|
        attrs.each { |k, v| q.send(:"#{k}=", v) if q.respond_to?(:"#{k}=") }
      end
    end
  end

  test "guide renders successfully" do
    get eviction_guide_guide_url
    assert_response :success
  end

  test "simulator renders successfully" do
    get eviction_guide_simulator_url
    assert_response :success
  end

  test "simulator with property_id pre-selects property" do
    property = properties(:safe_apartment)
    get eviction_guide_simulator_url(property_id: property.id)
    assert_response :success
  end

  test "create without occupant_type redirects to type selection" do
    post eviction_guide_simulation_url
    assert_redirected_to eviction_guide_simulator_select_type_path
  end

  test "create with valid occupant_type starts simulation" do
    post eviction_guide_simulation_url, params: { occupant_type: "junior_tenant" }
    sim = EvictionSimulation.order(:created_at).last
    assert_equal "junior_tenant", sim.occupant_type
  end

  test "select_type renders type selection page" do
    post eviction_guide_simulation_url
    get eviction_guide_simulator_select_type_url
    assert_response :success
  end

  test "full junior_tenant standalone flow via select_type" do
    # Step 1: Create without type → redirects to select_type
    post eviction_guide_simulation_url
    assert_redirected_to eviction_guide_simulator_select_type_path

    # Step 2: Select type via PATCH → updates existing simulation
    patch eviction_guide_simulation_url, params: { occupant_type: "junior_tenant" }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Step 3: Answer JT-Q1 through JT-Q6 = yes
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q1", answer: "true", next_code: "JT-Q2"
    }
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q2", answer: "true", next_code: "JT-Q3"
    }
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q3", answer: "true", next_code: "JT-Q4"
    }
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q4", answer: "true", next_code: "JT-Q5"
    }
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q5", answer: "true", next_code: "JT-Q6"
    }
    patch eviction_guide_simulation_url, params: {
      question_code: "JT-Q6", answer: "true", next_code: "END"
    }
    assert_redirected_to eviction_guide_simulation_path

    # Step 4: View result
    get eviction_guide_simulation_url
    assert_response :success
  end

  test "invalid occupant_type is rejected" do
    post eviction_guide_simulation_url, params: { occupant_type: "malicious_type" }
    sim = EvictionSimulation.order(:created_at).last
    assert_nil sim.occupant_type
    assert_redirected_to eviction_guide_simulator_select_type_path
  end
end
