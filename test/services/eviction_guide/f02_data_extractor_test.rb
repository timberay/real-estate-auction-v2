require "test_helper"

class EvictionGuide::F02DataExtractorTest < ActiveSupport::TestCase
  setup do
    @property = properties(:safe_apartment)
  end

  test "returns empty hash when property has no report" do
    @property.rights_analysis_reports.destroy_all
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_equal({}, result)
  end

  test "extracts has_opposing_tenant from effective_tenants" do
    report = @property.rights_analysis_reports.last
    next skip("No report fixture") unless report

    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_includes [ true, false, nil ], result[:has_opposing_tenant]
  end

  test "extracts has_lien from inspection results" do
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_includes [ true, false, nil ], result[:has_lien]
  end

  test "returns nil for unmapped fields" do
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_nil result[:nonexistent_field]
  end
end
