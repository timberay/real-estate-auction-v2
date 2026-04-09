require "test_helper"

class CourtAuction::ResponseParserTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    @fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
  end

  test "parses intercepted API response into normalized hash" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "parses raw_data fields for inspection runner" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "일괄매각", result[:remarks]
    assert_equal 2, result[:failed_bid_count]
    assert_equal false, result[:is_partial_share]
    assert_equal "", result[:special_conditions]
    assert_equal 45, result[:view_count]
  end

  test "returns nil when dlt_srchResult is empty" do
    empty = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    result = @parser.parse(api_response: empty)

    assert_nil result
  end

  test "raises ParseError when required fields are blank" do
    @fixture["data"]["dlt_srchResult"][0]["jiwonNm"] = ""

    assert_raises(DataProvider::ParseError) do
      @parser.parse(api_response: @fixture)
    end
  end

  test "raises ParseError when price field is missing" do
    @fixture["data"]["dlt_srchResult"][0]["gamevalAmt"] = ""

    assert_raises(DataProvider::ParseError) do
      @parser.parse(api_response: @fixture)
    end
  end

  test "raises ParseError when response structure is unexpected" do
    bad_response = { "status" => 200, "data" => {} }

    assert_raises(DataProvider::ParseError) do
      @parser.parse(api_response: bad_response)
    end
  end

  test "converts price strings to integers" do
    result = @parser.parse(api_response: @fixture)

    assert_kind_of Integer, result[:appraisal_price]
    assert_kind_of Integer, result[:min_bid_price]
  end

  test "mokGbncd 00 means not partial share" do
    @fixture["data"]["dlt_srchResult"][0]["mokGbncd"] = "00"
    result = @parser.parse(api_response: @fixture)
    assert_equal false, result[:is_partial_share]
  end

  test "mokGbncd 03 means partial share" do
    @fixture["data"]["dlt_srchResult"][0]["mokGbncd"] = "03"
    result = @parser.parse(api_response: @fixture)
    assert_equal true, result[:is_partial_share]
  end

  test "result has all keys that mock adapter returns" do
    result = @parser.parse(api_response: @fixture)

    core_keys = %i[case_number court_name property_type address appraisal_price min_bid_price
                   remarks is_partial_share failed_bid_count]
    core_keys.each do |key|
      assert result.key?(key), "Missing key: #{key}"
    end
  end
end
