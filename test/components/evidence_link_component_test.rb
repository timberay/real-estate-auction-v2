# frozen_string_literal: true

require "test_helper"

class EvidenceLinkComponentTest < ViewComponent::TestCase
  # --- All three fields present ---

  test "renders source_doc, page_number, and quote when all present" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "등기부등본",
      page_number: 3,
      quote: "을구 1번 주택임차권등기 — 배당에서 전액 변제받지 않으면 매수인이 인수"
    ))

    assert_text "등기부등본"
    assert_text "p.3"
    assert_selector "blockquote"
    assert_text "을구 1번 주택임차권등기"
  end

  test "wraps quote in blockquote element for semantic markup" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "매각물건명세서",
      page_number: 1,
      quote: "비고란에 유치권 신고가 있다는 기재가 확인됨"
    ))

    assert_selector "blockquote", text: /유치권 신고/
  end

  # --- Partial fields ---

  test "renders only source_doc when page_number and quote are nil" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "감정평가서",
      page_number: nil,
      quote: nil
    ))

    assert_text "감정평가서"
    refute_text "p."
    assert_no_selector "blockquote"
  end

  test "renders source_doc and page_number without quote" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "등기부등본",
      page_number: 5,
      quote: nil
    ))

    assert_text "등기부등본"
    assert_text "p.5"
    assert_no_selector "blockquote"
  end

  test "renders quote alone without source_doc or page_number" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: nil,
      page_number: nil,
      quote: "원문 인용 텍스트입니다."
    ))

    assert_selector "blockquote", text: /원문 인용 텍스트입니다/
  end

  test "skips bullet separator when page_number is nil" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "감정평가서",
      page_number: nil,
      quote: "원문 인용"
    ))

    html = page.native.inner_html
    refute_includes html, "·"
  end

  # --- Empty / nil cases ---

  test "renders nothing when all fields are nil" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: nil,
      page_number: nil,
      quote: nil
    ))

    assert_no_selector "[data-evidence-link]"
    assert_no_selector "blockquote"
  end

  test "renders nothing when all fields are blank strings" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "",
      page_number: nil,
      quote: ""
    ))

    assert_no_selector "[data-evidence-link]"
  end

  # --- XSS / escaping ---

  test "escapes HTML special characters in quote (XSS regression)" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "등기부등본",
      page_number: 1,
      quote: "<script>alert('xss')</script> & <b>bold</b>"
    ))

    html = page.native.inner_html
    refute_includes html, "<script>alert"
    refute_includes html, "<b>bold</b>"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&amp;"
  end

  test "escapes HTML special characters in source_doc" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "<img src=x onerror=alert(1)>",
      page_number: nil,
      quote: nil
    ))

    html = page.native.inner_html
    refute_includes html, "<img src=x"
    assert_includes html, "&lt;img"
  end

  # --- Container marker ---

  test "wrapper element carries data-evidence-link attribute" do
    render_inline(EvidenceLinkComponent.new(
      source_doc: "등기부등본",
      page_number: 3,
      quote: "원문 인용 50자 이상의 적당한 길이를 가진 문장입니다."
    ))

    assert_selector "[data-evidence-link]"
  end
end
