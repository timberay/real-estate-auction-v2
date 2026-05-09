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
end
