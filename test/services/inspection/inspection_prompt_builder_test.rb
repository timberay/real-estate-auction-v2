require "test_helper"

class Inspection::InspectionPromptBuilderTest < ActiveSupport::TestCase
  setup do
    @property_text = "[물건 기본 정보]\n사건번호: 2026타경10002\n물건종류: 빌라"
    @items = InspectionItem.where(tab: :rights_analysis).ordered
  end

  test "returns hash with system and user keys" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_kind_of Hash, result
    assert result.key?(:system)
    assert result.key?(:user)
  end

  test "system prompt contains expert persona" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:system], "부동산 경매 권리분석 전문가"
  end

  test "system prompt contains JSON response format" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:system], "has_risk"
    assert_includes result[:system], "confidence"
    assert_includes result[:system], "reasoning"
  end

  test "user prompt contains property data" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:user], "2026타경10002"
  end

  test "user prompt contains all inspection items with yes_means_safe flag" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    @items.each do |item|
      assert_includes result[:user], item.code
      assert_includes result[:user], "yes_means_safe=#{item.yes_means_safe?}"
    end
  end
end
