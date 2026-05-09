require "application_system_test_case"

class LegalPagesTest < ApplicationSystemTestCase
  test "terms page renders full content with required sections" do
    visit terms_path
    assert_text "이용약관"
    assert_text "AI 분석 결과의 한계 및 면책"
    assert_text "사용자 책임"
    refute_text "정식 출시 전 작성 중"
  end

  test "privacy page renders full content with required sections" do
    visit privacy_path
    assert_text "개인정보처리방침"
    assert_text "수집하는 개인정보 항목"
    assert_text "보유 및 이용 기간"
    assert_text "외부 LLM API 제공사"
    refute_text "정식 출시 전 작성 중"
  end
end
