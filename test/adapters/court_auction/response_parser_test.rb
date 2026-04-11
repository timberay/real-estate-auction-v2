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
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "parses location fields" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "서울특별시", result[:sido]
    assert_equal "강남구", result[:sigungu]
    assert_equal "역삼동", result[:dong]
  end

  test "parses building fields" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "테스트아파트", result[:building_name]
    assert_equal "101동 1001호", result[:building_detail]
    assert_equal "철근콩크리트조 84.50㎡", result[:building_structure]
    assert_in_delta 84.50, result[:exclusive_area], 0.01
  end

  test "parses geographic coordinates" do
    result = @parser.parse(api_response: @fixture)

    assert_in_delta 37.5012, result[:latitude], 0.0001
    assert_in_delta 127.0365, result[:longitude], 0.0001
  end

  test "parses status from mulJinYn" do
    result = @parser.parse(api_response: @fixture)
    assert_equal "진행중", result[:status]

    @fixture["data"]["dlt_srchResult"][0]["mulJinYn"] = "N"
    result = @parser.parse(api_response: @fixture)
    assert_equal "종결", result[:status]
  end

  test "parses count fields" do
    result = @parser.parse(api_response: @fixture)

    assert_equal 2, result[:failed_bid_count]
    assert_equal 45, result[:view_count]
    assert_equal 12, result[:interest_count]
  end

  test "parses special conditions and remarks" do
    result = @parser.parse(api_response: @fixture)

    assert_nil result[:special_conditions_code]
    assert_equal "일괄매각", result[:remarks]
  end

  test "returns nil when dlt_srchResult is empty" do
    empty = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    result = @parser.parse(api_response: empty)

    assert_nil result
  end

  test "raises ParseError when required fields are blank" do
    @fixture["data"]["dlt_srchResult"][0]["printSt"] = ""

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

  test "result has all expected keys" do
    result = @parser.parse(api_response: @fixture)

    expected_keys = %i[
      case_number property_type property_usage_code status
      address sido sigungu dong
      building_name building_detail building_structure exclusive_area
      appraisal_price min_bid_price
      failed_bid_count view_count interest_count
      latitude longitude
      special_conditions_code remarks
    ]
    expected_keys.each do |key|
      assert result.key?(key), "Missing key: #{key}"
    end
  end
end
