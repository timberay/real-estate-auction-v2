require "test_helper"

class EvictionGuide::DifficultyAssessorTest < ActiveSupport::TestCase
  test "returns low when no branches entered" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal "low", result
  end

  test "returns high when B1 branch entered" do
    answers = { "Q1" => false }
    questions = { "Q1" => EvictionSimulatorQuestion.new(
      code: "Q1", step_code: "S1", no_next_code: "Q1B",
      difficulty_impact: "high"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result
  end

  test "returns medium for medium-impact branches" do
    answers = { "Q7" => false }
    questions = { "Q7" => EvictionSimulatorQuestion.new(
      code: "Q7", step_code: "S7", no_next_code: "Q7B",
      difficulty_impact: "medium"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "medium", result
  end

  test "highest difficulty wins" do
    answers = { "Q1" => false, "Q7" => false }
    questions = {
      "Q1" => EvictionSimulatorQuestion.new(
        code: "Q1", step_code: "S1", no_next_code: "Q1B", difficulty_impact: "high"
      ),
      "Q7" => EvictionSimulatorQuestion.new(
        code: "Q7", step_code: "S7", no_next_code: "Q7B", difficulty_impact: "medium"
      )
    }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result
  end
end
