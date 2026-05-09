require "application_system_test_case"

class EvictionStepDetailTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:budget_user)
  end

  test "step detail page renders name, description, and estimated duration" do
    step = eviction_steps(:s1_rights_analysis)
    visit eviction_guide_step_detail_path(code: step.code)

    assert_text step.name
    assert_text step.description
    assert_text "예상 기간"
    assert_text step.estimated_duration
    assert_selector "article"
  end

  test "step detail page renders required documents when available as array" do
    step = EvictionStep.create!(
      code: "TSTSTEP",
      step_type: :main,
      name: "테스트 단계",
      description: "테스트 설명",
      required_documents: [ "등기부등본", "매각물건명세서" ],
      estimated_duration: "1~2주",
      position: 999
    )
    visit eviction_guide_step_detail_path(code: step.code)

    assert_text "필요 서류"
    assert_text "등기부등본"
    assert_text "매각물건명세서"
  ensure
    step&.destroy
  end

  test "step detail page is not a one-line stub" do
    step = eviction_steps(:s1_rights_analysis)
    visit eviction_guide_step_detail_path(code: step.code)

    assert_selector "h1", text: step.name
    assert_selector "dl"
  end

  test "branch detail page renders name, description, problem summary, and root cause" do
    branch = eviction_steps(:b1_deposit_risk)
    visit eviction_guide_branch_detail_path(code: branch.code)

    assert_text branch.name
    assert_text branch.description
    assert_text "문제 요약"
    assert_text branch.problem_summary
    assert_text "원인"
    assert_text branch.root_cause
    assert_selector "article"
  end

  test "branch detail page renders action steps when available as array" do
    branch = EvictionStep.create!(
      code: "TSTBRANCH",
      step_type: :branch,
      name: "테스트 분기",
      description: "테스트 분기 설명",
      problem_summary: "테스트 문제",
      root_cause: "테스트 원인",
      action_steps: [ "조치1", "조치2" ],
      estimated_duration: "1~2주",
      position: 998,
      trigger_step_code: "S1"
    )
    visit eviction_guide_branch_detail_path(code: branch.code)

    assert_text "조치 단계"
    assert_text "조치1"
    assert_text "조치2"
  ensure
    branch&.destroy
  end

  test "branch detail page is not a one-line stub" do
    branch = eviction_steps(:b1_deposit_risk)
    visit eviction_guide_branch_detail_path(code: branch.code)

    assert_selector "h1", text: branch.name
    assert_selector "article"
  end
end
