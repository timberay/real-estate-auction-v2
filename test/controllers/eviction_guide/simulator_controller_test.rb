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

  test "question 404 renders friendly message with start CTA when no simulation" do
    get eviction_guide_simulator_question_url(code: "JT-Q99")
    assert_response :not_found
    assert_select "h1", text: /질문을 찾을 수 없습니다/
    assert_select "a[href=?]", eviction_guide_simulator_path, text: /시뮬레이터 시작하기/
    assert_select "a", { text: /이어가기/, count: 0 }
  end

  test "question 404 shows resume CTA when simulation has answers" do
    post eviction_guide_simulation_url, params: { property_id: "" }
    patch eviction_guide_simulation_url, params: {
      occupant_type: "junior_tenant"
    }

    get eviction_guide_simulator_question_url(code: "JT-Q99")
    assert_response :not_found
    assert_select "h1", text: /질문을 찾을 수 없습니다/
    assert_select "a", text: /이어가기/
  end
end
