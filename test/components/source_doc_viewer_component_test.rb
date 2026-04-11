require "test_helper"

class SourceDocViewerComponentTest < ViewComponent::TestCase
  test "renders empty registry transcript message when no data" do
    property = properties(:safe_apartment)
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "등기부등본 데이터가 없습니다"
  end

  test "renders disclaimer" do
    property = properties(:safe_apartment)
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "매각물건명세서 비고란을 직접 확인하세요"
  end
end
