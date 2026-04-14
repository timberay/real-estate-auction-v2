require "test_helper"

class EvictionSimulatorQuestionTest < ActiveSupport::TestCase
  test "valid question" do
    q = EvictionSimulatorQuestion.new(
      code: "Q99", phase: "summary", step_code: "S1",
      question: "테스트 질문?"
    )
    assert q.valid?
  end

  test "code must be unique" do
    dup = EvictionSimulatorQuestion.new(
      code: eviction_simulator_questions(:q1_rights_done).code,
      phase: "summary", step_code: "S1", question: "중복?"
    )
    assert_not dup.valid?
  end

  test "phase enum" do
    q = EvictionSimulatorQuestion.new(phase: "summary")
    assert q.summary?
    q.phase = "detail"
    assert q.detail?
  end
end
