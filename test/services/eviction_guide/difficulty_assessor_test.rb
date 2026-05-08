require "test_helper"

class EvictionGuide::DifficultyAssessorTest < ActiveSupport::TestCase
  test "returns low when no branches entered" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal "low", result.level
  end

  test "returns high when B1 branch entered" do
    answers = { "Q1" => false }
    questions = { "Q1" => EvictionSimulatorQuestion.new(
      code: "Q1", step_code: "S1", no_next_code: "Q1B",
      difficulty_impact: "high"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result.level
  end

  test "returns medium for medium-impact branches" do
    answers = { "Q7" => false }
    questions = { "Q7" => EvictionSimulatorQuestion.new(
      code: "Q7", step_code: "S7", no_next_code: "Q7B",
      difficulty_impact: "medium"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "medium", result.level
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
    assert_equal "high", result.level
  end

  test "returns base difficulty for junior_tenant with all-yes answers" do
    answers = { "JT-Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "junior_tenant")
    assert_equal "low", result.level
  end

  test "returns base difficulty for senior_tenant with all-yes answers" do
    answers = { "ST-Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "senior_tenant")
    assert_equal "high", result.level
  end

  test "base difficulty overridden by higher answer-based difficulty" do
    answers = { "JT-Q1" => false }
    questions = {
      "JT-Q1" => EvictionSimulatorQuestion.new(
        code: "JT-Q1", step_code: "JT-S1", no_next_code: "JT-Q1G",
        difficulty_impact: "high", occupant_type: "junior_tenant"
      )
    }
    result = EvictionGuide::DifficultyAssessor.call(
      answers, occupant_type: "junior_tenant", questions: questions
    )
    assert_equal "high", result.level
  end

  test "base difficulty wins when answer-based is lower" do
    answers = { "DO-Q1" => false }
    questions = {
      "DO-Q1" => EvictionSimulatorQuestion.new(
        code: "DO-Q1", step_code: "DO-S1", no_next_code: "DO-Q1G",
        difficulty_impact: "low", occupant_type: "debtor_owner"
      )
    }
    result = EvictionGuide::DifficultyAssessor.call(
      answers, occupant_type: "debtor_owner", questions: questions
    )
    assert_equal "medium", result.level
  end

  test "legacy behavior unchanged when occupant_type is nil" do
    answers = { "Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: nil)
    assert_equal "low", result.level
  end

  test "Result#to_s returns level for back-compat" do
    answers = { "Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal result.level, result.to_s
    assert_equal "low", "#{result}"
  end
end
