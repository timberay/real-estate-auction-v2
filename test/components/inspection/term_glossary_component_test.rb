require "test_helper"

class Inspection::TermGlossaryComponentTest < ViewComponent::TestCase
  test "wraps a known glossary term in a clickable span" do
    render_inline(Inspection::TermGlossaryComponent.new(text: "임차인이 거주하고 있습니까?"))

    assert_selector "[data-controller='glossary']", text: "임차인"
  end

  test "attaches definition data attribute to the term span" do
    render_inline(Inspection::TermGlossaryComponent.new(text: "대항력 확인이 필요합니다."))

    span = page.find("[data-controller='glossary'][data-glossary-term='대항력']")
    assert span["data-glossary-definition-value"].present?
  end

  test "plain text with no glossary terms renders without glossary spans" do
    render_inline(Inspection::TermGlossaryComponent.new(text: "일반 텍스트입니다."))

    assert_no_selector "[data-controller='glossary']"
    assert_text "일반 텍스트입니다."
  end

  test "escapes HTML in the input text" do
    render_inline(Inspection::TermGlossaryComponent.new(text: "<script>alert(1)</script>"))

    assert_no_selector "script"
  end

  test "annotates multiple terms in one sentence" do
    text = "유치권과 법정지상권 모두 확인하세요."
    render_inline(Inspection::TermGlossaryComponent.new(text: text))

    assert_selector "[data-controller='glossary']", minimum: 2
  end

  test "loads at least 15 glossary terms" do
    assert Inspection::TermGlossaryComponent.glossary.size >= 15
  end

  test "glossary includes required terms" do
    terms = Inspection::TermGlossaryComponent.glossary.keys
    %w[대항력 말소기준권리 유치권 가등기 가처분 법정지상권 임차인 매각물건명세서].each do |term|
      assert_includes terms, term, "glossary missing term: #{term}"
    end
  end
end
