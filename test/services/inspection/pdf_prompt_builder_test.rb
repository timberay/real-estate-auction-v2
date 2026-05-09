require "test_helper"

class Inspection::PdfPromptBuilderTest < ActiveSupport::TestCase
  test "builds system prompt with metadata extraction and judgment rules" do
    items = InspectionItem.ordered.limit(3)
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:system].include?("부동산 경매 권리분석 전문가")
    assert result[:system].include?("메타데이터 추출")
    assert result[:system].include?("점검항목 판정")
    assert result[:system].include?("court_name")
    assert result[:system].include?("case_number")
  end

  test "builds user prompt with inspection item codes and questions" do
    items = InspectionItem.ordered.limit(3)
    result = Inspection::PdfPromptBuilder.call(items: items)

    items.each do |item|
      assert result[:user].include?(item.code), "Missing item code: #{item.code}"
      assert result[:user].include?(item.question[0..30]), "Missing item question: #{item.question[0..30]}"
    end
  end

  test "includes yes_means_safe and priority for each item" do
    items = InspectionItem.where(code: "rights-008").to_a
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:user].include?("yes_means_safe=false")
    assert result[:user].include?("priority=상")
  end

  test "includes confirmed_date field in tenant schema" do
    items = InspectionItem.ordered.limit(1)
    result = Inspection::PdfPromptBuilder.call(items: items)
    assert result[:system].include?("confirmed_date")
  end

  test "includes HUG opportunity detection instructions" do
    items = InspectionItem.ordered.limit(1)
    result = Inspection::PdfPromptBuilder.call(items: items)
    assert result[:system].include?("주택도시보증공사")
    assert result[:system].include?("hug_waiver")
  end

  test "tenants schema in SYSTEM_PROMPT requires dividend_requested field" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    assert_match(/dividend_requested/, prompt, "tenants schema must include dividend_requested field")
    assert_match(/배당요구/, prompt, "prompt must instruct LLM to extract 배당요구 column")
  end

  # --- B4 / E-10: contradiction detection rule ---

  test "prompt instructs cross-reference between 등기부등본 and 매각물건명세서 for contradictions" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    assert_includes prompt, "등기부", "prompt must reference 등기부"
    assert_includes prompt, "매각물건명세서", "prompt must reference 매각물건명세서"
    assert(prompt.include?("모순") || prompt.include?("불일치"),
      "prompt must include a contradiction-related keyword (모순 or 불일치)")
  end

  test "prompt instructs setting verdict to caution on contradiction" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    contradiction_section = prompt[/\[(?:모순 검출 규칙|자기검증)\].*?(?=\[)/m]
    assert contradiction_section.present?,
      "prompt must contain a [모순 검출 규칙] or [자기검증] section"
    assert_includes contradiction_section, "caution",
      "contradiction section must instruct setting verdict to caution"
    assert(contradiction_section.include?("모순") || contradiction_section.include?("불일치"),
      "contradiction section must mention 모순 or 불일치 alongside caution")
  end

  test "prompt provides at least one concrete contradiction example" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    examples = [ "근저당", "가압류", "임차인 정보", "권리 설정일" ]
    matched = examples.any? { |ex| prompt.include?(ex) }
    assert matched,
      "prompt must include at least one concrete contradiction example: #{examples.join(', ')}"
  end

  test "prompt requires reasoning to cite both documents on contradiction" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    contradiction_section = prompt[/\[(?:모순 검출 규칙|자기검증)\].*?(?=\[)/m]
    assert contradiction_section.present?,
      "prompt must contain a [모순 검출 규칙] or [자기검증] section"
    assert_includes contradiction_section, "reasoning",
      "contradiction section must reference reasoning field"
    assert(contradiction_section.include?("양쪽") || contradiction_section.include?("모두 인용"),
      "contradiction section must require citing both documents (양쪽 or 모두 인용)")
  end

  # --- B7 / E-19: source citation fields ---

  test "prompt requires source_doc / page_number / quote on evidence" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    assert_match(/source_doc/, prompt, "prompt must require source_doc field")
    assert_match(/page_number/, prompt, "prompt must require page_number field")
    assert_match(/quote/, prompt, "prompt must require quote field")
  end

  test "prompt allows null source_doc when confidence is none" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    assert_match(
      /confidence가\s*["']none["']이거나.+has_risk가\s*null.+source_doc/m,
      prompt,
      "prompt must explicitly relax citation requirement for none/null cases"
    )
  end

  test "prompt forbids paraphrasing in quote" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    assert_match(/의역\s*금지/, prompt, "prompt must forbid paraphrasing the quote")
  end

  test "prompt schema example includes source_doc / page_number / quote in results block" do
    prompt = Inspection::PdfPromptBuilder::SYSTEM_PROMPT
    # Ensure the citation fields appear in the JSON example for `results.<item_code>`
    results_section = prompt[/"results":\s*\{.*?\}\s*\}/m]
    assert results_section.present?, "results JSON example must exist"
    assert_includes results_section, "source_doc"
    assert_includes results_section, "page_number"
    assert_includes results_section, "quote"
  end
end
