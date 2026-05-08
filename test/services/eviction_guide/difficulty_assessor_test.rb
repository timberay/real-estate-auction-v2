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

  test "base reports level and occupant_type" do
    result = EvictionGuide::DifficultyAssessor.call({}, occupant_type: "debtor_owner")
    assert_equal "medium", result.base[:level]
    assert_equal "debtor_owner", result.base[:occupant_type]
  end

  test "base level is nil when occupant_type is nil" do
    result = EvictionGuide::DifficultyAssessor.call({})
    assert_nil result.base[:level]
    assert_nil result.base[:occupant_type]
  end

  test "triggers is empty when no no-answer escalates difficulty" do
    answers = { "Q1" => true, "Q2" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "debtor_owner")
    assert_empty result.triggers
  end

  test "triggers includes code, step_code, step_name, impact, help_text" do
    answers = { "Q5" => false }
    questions = { "Q5" => EvictionSimulatorQuestion.new(
      code: "Q5", step_code: "S5", no_next_code: "Q5B",
      difficulty_impact: "high",
      help_text: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다."
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    assert_equal 1, result.triggers.size
    trigger = result.triggers.first
    assert_equal "Q5", trigger[:code]
    assert_equal "S5", trigger[:step_code]
    assert_equal "인도명령 + 점유이전금지가처분 동시 신청", trigger[:step_name]
    assert_equal "high", trigger[:impact]
    assert_equal "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다.", trigger[:help_text]
  end

  test "triggers preserves answer order" do
    answers = { "Q5" => false, "Q14G" => false }
    questions = {
      "Q5" => EvictionSimulatorQuestion.new(
        code: "Q5", step_code: "S5", no_next_code: "Q5B",
        difficulty_impact: "high", help_text: "high impact help"
      ),
      "Q14G" => EvictionSimulatorQuestion.new(
        code: "Q14G", step_code: "S14", no_next_code: "Q14R",
        difficulty_impact: "medium", help_text: "medium impact help"
      )
    }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    assert_equal %w[Q5 Q14G], result.triggers.map { |t| t[:code] }
  end

  test "triggers uses step_code as step_name fallback when step row is missing" do
    answers = { "QX" => false }
    questions = { "QX" => EvictionSimulatorQuestion.new(
      code: "QX", step_code: "S-NONEXISTENT", no_next_code: "QXB",
      difficulty_impact: "medium", help_text: "no step row"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    trigger = result.triggers.first
    assert_equal "S-NONEXISTENT", trigger[:step_code]
    assert_equal "S-NONEXISTENT", trigger[:step_name]
  end
end
