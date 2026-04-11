require "test_helper"

class SourceDocViewerComponentTest < ViewComponent::TestCase
  test "renders registry transcript data" do
    property = properties(:safe_apartment)
    property.raw_data = { "registry_transcript" => { "rights" => [ { "type" => "근저당" } ], "tenants" => [], "hug_waiver" => false, "seizures" => [] } }
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "등기부등본"
    assert_text "1건"
  end

  test "renders disclaimer" do
    property = properties(:safe_apartment)
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "매각물건명세서 비고란을 직접 확인하세요"
  end
end
