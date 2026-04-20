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

  test "for_occupant_type returns only matching occupant_type questions" do
    jt_questions = EvictionSimulatorQuestion.for_occupant_type("junior_tenant")
    assert jt_questions.any?
    jt_questions.each { |q| assert_equal "junior_tenant", q.occupant_type }
  end

  test "for_occupant_type with nil returns only legacy questions" do
    legacy_questions = EvictionSimulatorQuestion.for_occupant_type(nil)
    assert legacy_questions.any?
    legacy_questions.each { |q| assert_nil q.occupant_type }
  end

  test "phase enum" do
    q = EvictionSimulatorQuestion.new(phase: "summary")
    assert q.summary?
    q.phase = "detail"
    assert q.detail?
  end

  test "branch? returns false for main question codes" do
    %w[Q1 Q2 Q15 JT-Q1 JT-Q6].each do |code|
      q = EvictionSimulatorQuestion.new(code: code)
      assert_not q.branch?, "#{code} should not be a branch question"
    end
  end

  test "branch? returns true for branch question codes (letter suffix)" do
    %w[Q1G Q1R Q5B Q5C Q13A JT-Q1G JT-Q5G].each do |code|
      q = EvictionSimulatorQuestion.new(code: code)
      assert q.branch?, "#{code} should be a branch question"
    end
  end
end
