require "test_helper"

class SourceDocViewerComponentTest < ViewComponent::TestCase
  test "renders court auction data" do
    property = properties(:safe_apartment)
    property.raw_data = { "court_auction" => { "remarks" => "해당사항 없음", "lien_reported" => false }, "registry_transcript" => {} }
    render_inline(SourceDocViewerComponent.new(property: property))
    assert_text "매각물건명세서"
    assert_text "해당사항 없음"
  end

  test "renders registry transcript data" do
    property = properties(:safe_apartment)
    property.raw_data = { "court_auction" => {}, "registry_transcript" => { "rights" => [ { "type" => "근저당" } ], "tenants" => [], "hug_waiver" => false, "seizures" => [] } }
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
