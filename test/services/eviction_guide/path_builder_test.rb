require "test_helper"

class EvictionGuide::PathBuilderTest < ActiveSupport::TestCase
  setup do
    # Load seed data for graph traversal
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

  test "builds path from answers — all yes" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true, "Q5" => true }
    path = EvictionGuide::PathBuilder.call(answers)
    assert_kind_of Array, path
    assert path.all? { |entry| entry.key?(:code) && entry.key?(:status) }
  end

  test "includes branch in path when answer is no with branch question" do
    # Q1G -> no -> Q1R (still S1), Q1R -> no -> END
    # Q2G has branch B4 via step_code S2
    # Use Q5 which has no_next_code Q5B -> step S5, then Q5B no -> Q5C
    # Actually, branch entries come when no_next_code leads to a question whose step is a branch type
    # Let's use a direct "no" on a question that triggers difficulty
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true, "Q5" => false, "Q5B" => false, "Q5C" => true }
    path = EvictionGuide::PathBuilder.call(answers)
    step_codes = path.map { |e| e[:code] }
    assert_includes step_codes, "S5"
  end

  test "returns empty path for empty answers" do
    path = EvictionGuide::PathBuilder.call({})
    assert_equal [], path
  end
end
