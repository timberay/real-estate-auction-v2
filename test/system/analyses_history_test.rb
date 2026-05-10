require "application_system_test_case"

# B15 / E-44: AI 분석 이력. The property show page must link to a history view
# that lists provider / model / executed_at / status for each LlmAnalysisLog.
class AnalysesHistoryTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:budget_user)
    UserProperty.find_or_create_by!(user: @user, property: @property)

    LlmAnalysisLog.create!(
      property: @property, user: @user,
      system_prompt: "s", user_prompt: "u",
      provider: "anthropic", model: "claude-opus-4",
      status: :completed, executed_at: Time.zone.local(2026, 5, 9, 14, 30)
    )
    LlmAnalysisLog.create!(
      property: @property, user: @user,
      system_prompt: "s", user_prompt: "u",
      provider: "openai", model: "gpt-5",
      status: :failed, error_message: "rate limited",
      executed_at: Time.zone.local(2026, 5, 10, 9, 0)
    )

    sign_in_as(@user)
  end

  test "property show links to AI 분석 이력 page" do
    visit property_path(@property)

    assert_link "분석 이력 보기"
  end

  test "history page lists provider, model, executed_at, status" do
    visit history_analyses_path(property_id: @property.id)

    assert_selector "h3", text: "AI 분석 이력"

    # Both rows visible.
    assert_text "anthropic"
    assert_text "claude-opus-4"
    assert_text "openai"
    assert_text "gpt-5"

    # Korean status labels.
    assert_text "완료"
    assert_text "실패"

    # Executed timestamps formatted YYYY.MM.DD HH:MM.
    assert_text "2026.05.10 09:00"
    assert_text "2026.05.09 14:30"

    # Failure error message visible.
    assert_text "rate limited"
  end

  test "history page renders empty state when no logs" do
    @property.llm_analysis_logs.destroy_all

    visit history_analyses_path(property_id: @property.id)

    assert_text "분석 이력이 없습니다"
  end
end
