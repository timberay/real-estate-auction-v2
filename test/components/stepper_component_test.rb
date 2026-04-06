require "test_helper"

class StepperComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "renders 3 steps with correct labels" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_text "체크리스트"
    assert_text "권리 분석"
    assert_text "등급 산정"
    assert_no_text "기본 정보"
  end

  test "marks active step with active status" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "[data-step-status='active']", text: "권리 분석"
  end

  test "always shows step numbers even when completed" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "[data-step-status='completed']", text: "1."
    assert_no_text "✓"
  end

  test "marks pending steps with pending status" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-step-status='pending']", text: "권리 분석"
    assert_selector "[data-step-status='pending']", text: "등급 산정"
  end

  test "completed steps are clickable links" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "a[data-step-status='completed'][href]", text: "체크리스트"
  end

  test "pending steps have turbo frame target" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-turbo-frame='tab_content']", count: 3
  end

  test "report step is pending when user_confirmed_at is nil" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    report = RightsAnalysisReport.find_or_create_by!(user: @user, property: @property) do |r|
      r.verdict = :safe
      r.verdict_summary = "test"
      r.analyzed_at = Time.current
    end
    report.update!(user_confirmed_at: nil)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-step-status='pending'][data-step-key='report']"
  end

  test "report step is completed when user_confirmed_at is present" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    report = RightsAnalysisReport.find_or_create_by!(user: @user, property: @property) do |r|
      r.verdict = :safe
      r.verdict_summary = "test"
      r.analyzed_at = Time.current
    end
    report.update!(user_confirmed_at: Time.current)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-step-status='completed'][data-step-key='report']"
  end
end
