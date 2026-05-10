require "test_helper"

class EvictionStepTest < ActiveSupport::TestCase
  test "valid main step" do
    step = EvictionStep.new(
      code: "S99", step_type: "main", name: "테스트",
      description: "테스트 단계", position: 99
    )
    assert step.valid?
  end

  test "code must be unique" do
    dup = EvictionStep.new(
      code: eviction_steps(:s1_rights_analysis).code,
      step_type: "main", name: "중복", description: "중복", position: 99
    )
    assert_not dup.valid?
    assert_includes dup.errors[:code], "은(는) 이미 사용 중입니다"
  end

  test "step_type enum" do
    step = EvictionStep.new(step_type: "main")
    assert step.main?
    step.step_type = "branch"
    assert step.branch?
  end

  test "main scope returns only main steps" do
    main_steps = EvictionStep.main.ordered
    main_steps.each { |s| assert s.main? }
  end

  test "branch scope returns only branches" do
    branches = EvictionStep.branch
    branches.each { |s| assert s.branch? }
  end

  test "for_occupant_type returns only matching occupant_type steps" do
    jt_steps = EvictionStep.for_occupant_type("junior_tenant")
    assert jt_steps.any?
    jt_steps.each { |s| assert_equal "junior_tenant", s.occupant_type }
  end

  test "for_occupant_type with nil returns only legacy steps" do
    legacy_steps = EvictionStep.for_occupant_type(nil)
    assert legacy_steps.any?
    legacy_steps.each { |s| assert_nil s.occupant_type }
  end

  test "branches_for returns branches triggered by a main step" do
    s1 = eviction_steps(:s1_rights_analysis)
    branches = EvictionStep.branches_for(s1.code)
    branches.each do |b|
      assert_equal s1.code, b.trigger_step_code
    end
  end
end
