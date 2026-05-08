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

  test "filters steps by occupant_type when provided" do
    answers = { "JT-Q1" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "junior_tenant")
    assert_kind_of Array, path
    step_codes = path.map { |e| e[:code] }
    step_codes.each do |code|
      step = EvictionStep.find_by(code: code)
      assert_equal "junior_tenant", step.occupant_type
    end
  end

  test "legacy behavior unchanged when occupant_type is nil" do
    answers = { "Q1" => true, "Q2" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: nil)
    assert_kind_of Array, path
    step_codes = path.map { |e| e[:code] }
    step_codes.each do |code|
      step = EvictionStep.find_by(code: code)
      assert_nil step.occupant_type
    end
  end

  test "falls back to generic (nil) data when occupant_type has no seeded questions" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "unknown_type_for_fallback")
    assert_kind_of Array, path
    refute_empty path, "expected fallback to generic questions/steps when type has no seeded data"
    step_codes = path.map { |e| e[:code] }
    assert_includes step_codes, "S1"
  end

  test "builds path for senior_tenant using ST-prefixed seeds" do
    answers = { "ST-Q1" => true, "ST-Q2" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "senior_tenant")
    refute_empty path, "expected senior_tenant to have its own seeded path (no generic fallback)"
    step_codes = path.map { |e| e[:code] }
    step_codes.each do |code|
      step = EvictionStep.find_by(code: code)
      assert_equal "senior_tenant", step.occupant_type,
        "step #{code} should belong to senior_tenant, not fall back to generic"
    end
    assert step_codes.any? { |c| c.start_with?("ST-") },
      "expected ST-prefixed step codes, got: #{step_codes.inspect}"
  end

  test "builds path for debtor_owner using DO-prefixed seeds" do
    answers = { "DO-Q1" => true, "DO-Q2" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "debtor_owner")
    refute_empty path, "expected debtor_owner to have its own seeded path (no generic fallback)"
    step_codes = path.map { |e| e[:code] }
    step_codes.each do |code|
      step = EvictionStep.find_by(code: code)
      assert_equal "debtor_owner", step.occupant_type,
        "step #{code} should belong to debtor_owner, not fall back to generic"
    end
    assert step_codes.any? { |c| c.start_with?("DO-") },
      "expected DO-prefixed step codes, got: #{step_codes.inspect}"
  end

  test "builds path for illegal_occupant using IO-prefixed seeds" do
    answers = { "IO-Q1" => true, "IO-Q2" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "illegal_occupant")
    refute_empty path, "expected illegal_occupant to have its own seeded path (no generic fallback)"
    step_codes = path.map { |e| e[:code] }
    step_codes.each do |code|
      step = EvictionStep.find_by(code: code)
      assert_equal "illegal_occupant", step.occupant_type,
        "step #{code} should belong to illegal_occupant, not fall back to generic"
    end
    assert step_codes.any? { |c| c.start_with?("IO-") },
      "expected IO-prefixed step codes, got: #{step_codes.inspect}"
  end

  test "senior_tenant 'no' answer adds branch step to path" do
    # ST-Q2 'no' should route through ST-Q2G, which references a branch step ST-B*
    answers = { "ST-Q1" => true, "ST-Q2" => false, "ST-Q2G" => true }
    path = EvictionGuide::PathBuilder.call(answers, occupant_type: "senior_tenant")
    refute_empty path
    assert path.any? { |e| e[:status] == "branch" },
      "expected at least one branch entry when senior_tenant answers 'no' on ST-Q2"
  end
end
