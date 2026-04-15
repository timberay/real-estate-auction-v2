require "test_helper"

class EvictionSeedGraphValidationTest < ActiveSupport::TestCase
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

  test "all next_step_code values resolve to valid steps" do
    EvictionStep.main.for_occupant_type(nil).where.not(next_step_code: nil).find_each do |step|
      target = EvictionStep.find_by(code: step.next_step_code)
      assert target, "Step #{step.code} points to missing next_step_code: #{step.next_step_code}"
    end
  end

  test "all branch_codes resolve to valid branch steps" do
    EvictionStep.main.for_occupant_type(nil).find_each do |step|
      codes = step.branch_codes
      next unless codes.present?
      codes = JSON.parse(codes) if codes.is_a?(String)
      codes.each do |bcode|
        target = EvictionStep.find_by(code: bcode)
        assert target, "Step #{step.code} references missing branch: #{bcode}"
        assert target.branch?, "Step #{step.code} branch_code #{bcode} is not a branch type"
      end
    end
  end

  test "all return_step_code values resolve to valid main steps" do
    EvictionStep.branch.for_occupant_type(nil).where.not(return_step_code: nil).find_each do |branch|
      target = EvictionStep.find_by(code: branch.return_step_code)
      assert target, "Branch #{branch.code} points to missing return_step_code: #{branch.return_step_code}"
      assert target.main?, "Branch #{branch.code} return_step_code #{branch.return_step_code} is not a main type"
    end
  end

  test "all trigger_step_code values resolve to valid main steps" do
    EvictionStep.branch.for_occupant_type(nil).find_each do |branch|
      next unless branch.trigger_step_code
      target = EvictionStep.find_by(code: branch.trigger_step_code)
      assert target, "Branch #{branch.code} has missing trigger_step_code: #{branch.trigger_step_code}"
      assert target.main?, "Branch #{branch.code} trigger #{branch.trigger_step_code} is not main"
    end
  end

  test "all yes_next_code and no_next_code resolve to valid questions or END" do
    EvictionSimulatorQuestion.for_occupant_type(nil).find_each do |q|
      [ q.yes_next_code, q.no_next_code ].compact.each do |code|
        next if code == "END"
        target = EvictionSimulatorQuestion.find_by(code: code)
        assert target, "Question #{q.code} points to missing code: #{code}"
      end
    end
  end

  test "Q1 exists as entry point" do
    q1 = EvictionSimulatorQuestion.find_by(code: "Q1")
    assert q1, "Entry point Q1 must exist"
    assert q1.summary?, "Q1 must be summary phase"
  end

  test "no orphan questions — all are reachable from Q1" do
    all_codes = EvictionSimulatorQuestion.for_occupant_type(nil).pluck(:code).to_set
    reachable = Set.new
    queue = [ "Q1" ]

    while queue.any?
      code = queue.shift
      next if reachable.include?(code) || code == "END"
      reachable << code
      q = EvictionSimulatorQuestion.find_by(code: code)
      next unless q
      queue << q.yes_next_code if q.yes_next_code
      queue << q.no_next_code if q.no_next_code
    end

    orphans = all_codes - reachable
    assert orphans.empty?, "Orphan questions not reachable from Q1: #{orphans.to_a.join(', ')}"
  end

  # --- junior_tenant graph validation ---

  test "JT: all next_step_code values resolve" do
    EvictionStep.main.for_occupant_type("junior_tenant").where.not(next_step_code: nil).find_each do |step|
      target = EvictionStep.find_by(code: step.next_step_code)
      assert target, "Step #{step.code} points to missing next_step_code: #{step.next_step_code}"
    end
  end

  test "JT: all branch_codes resolve to valid branch steps" do
    EvictionStep.main.for_occupant_type("junior_tenant").find_each do |step|
      codes = step.branch_codes
      next unless codes.present?
      codes = JSON.parse(codes) if codes.is_a?(String)
      codes.each do |bcode|
        target = EvictionStep.find_by(code: bcode)
        assert target, "Step #{step.code} references missing branch: #{bcode}"
        assert target.branch?, "Step #{step.code} branch_code #{bcode} is not a branch type"
      end
    end
  end

  test "JT: all return_step_code values resolve" do
    EvictionStep.branch.for_occupant_type("junior_tenant").where.not(return_step_code: nil).find_each do |branch|
      target = EvictionStep.find_by(code: branch.return_step_code)
      assert target, "Branch #{branch.code} points to missing return_step_code: #{branch.return_step_code}"
      assert target.main?, "Branch #{branch.code} return_step_code #{branch.return_step_code} is not main"
    end
  end

  test "JT: all yes_next_code and no_next_code resolve" do
    EvictionSimulatorQuestion.for_occupant_type("junior_tenant").find_each do |q|
      [ q.yes_next_code, q.no_next_code ].compact.each do |code|
        next if code == "END"
        target = EvictionSimulatorQuestion.find_by(code: code)
        assert target, "Question #{q.code} points to missing code: #{code}"
      end
    end
  end

  test "JT: JT-Q1 exists as entry point" do
    q1 = EvictionSimulatorQuestion.find_by(code: "JT-Q1")
    assert q1, "Entry point JT-Q1 must exist"
    assert_equal "junior_tenant", q1.occupant_type
  end

  test "JT: no orphan questions — all reachable from JT-Q1" do
    all_codes = EvictionSimulatorQuestion.for_occupant_type("junior_tenant").pluck(:code).to_set
    reachable = Set.new
    queue = [ "JT-Q1" ]

    while queue.any?
      code = queue.shift
      next if reachable.include?(code) || code == "END"
      reachable << code
      q = EvictionSimulatorQuestion.find_by(code: code)
      next unless q
      queue << q.yes_next_code if q.yes_next_code
      queue << q.no_next_code if q.no_next_code
    end

    orphans = all_codes - reachable
    assert orphans.empty?, "Orphan JT questions not reachable from JT-Q1: #{orphans.to_a.join(', ')}"
  end
end
