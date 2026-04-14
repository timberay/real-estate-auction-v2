require "test_helper"

class EvictionGuide::SimulatorControllerTest < ActionDispatch::IntegrationTest
  test "question renders turbo frame" do
    get eviction_guide_simulator_question_url(code: "Q1")
    assert_response :success
  end

  test "question returns 404 for invalid code" do
    get eviction_guide_simulator_question_url(code: "INVALID")
    assert_response :not_found
  end
end
