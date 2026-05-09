# frozen_string_literal: true

require "application_system_test_case"

class LlmDataDisclosureTest < ApplicationSystemTestCase
  setup do
    visit root_path  # establish guest session
    @user = User.last

    @property = Property.create!(case_number: "2026타경88001", court_name: "서울중앙지방법원")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "AI auto tab is disabled with clear status badge" do
    visit new_analysis_path

    auto_tab = find("button", text: /AI 자동분석/)
    assert auto_tab[:"aria-disabled"] == "true",
           "AI auto tab must be aria-disabled=\"true\""
    assert_text "일시 중단"
  end

  test "data-disclosure panel lists what is sent and retention policy" do
    visit new_analysis_path

    assert_text "외부 LLM API로 전송되는 정보"
    assert_text "PDF의 추출된 텍스트"
    assert_text "1회 분석 후 즉시 폐기"
    assert_text "주소·주민등록번호는 자동 마스킹"
  end
end
