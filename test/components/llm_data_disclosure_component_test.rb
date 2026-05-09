# frozen_string_literal: true

require "test_helper"

class LlmDataDisclosureComponentTest < ViewComponent::TestCase
  setup do
    render_inline(LlmDataDisclosureComponent.new)
  end

  test "renders the disclosure heading" do
    assert_text "외부 LLM API로 전송되는 정보"
  end

  test "renders all four disclosure items" do
    assert_selector "dt", text: "전송 항목:"
    assert_selector "dt", text: "제공처:"
    assert_selector "dt", text: "보유 기간:"
    assert_selector "dt", text: "개인정보 처리:"
  end

  test "discloses extracted text only" do
    assert_text "PDF의 추출된 텍스트만 전송됩니다"
  end

  test "discloses immediate disposal after one analysis" do
    assert_text "1회 분석 후 즉시 폐기"
  end

  test "discloses address masking" do
    assert_text "주소·주민등록번호는 자동 마스킹"
  end

  test "links to privacy policy" do
    assert_selector "a[href='/privacy']", text: "개인정보처리방침"
  end
end
