require "test_helper"
require "json"

class CourtAuction::ResponseParserCaseSearchTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    fixture_path = Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json")
    @api_data = JSON.parse(File.read(fixture_path))["data"]
  end

  test "extracts case_number from userCsNo" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "2022타경564", result[:case_number]
  end

  test "extracts court_code and court_name from dma_csBasInf" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "B000530", result[:court_code]
    assert_equal "제주지방법원", result[:court_name]
  end

  test "extracts case_type from csNm" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "부동산임의경매", result[:case_type]
  end

  test "maps csProgStatCd starting with 0002 to 진행중" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "진행중", result[:status]
  end

  test "maps non-0002 csProgStatCd to 종결" do
    @api_data["dma_csBasInf"]["csProgStatCd"] = "0003100001"
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "종결", result[:status]
  end

  test "extracts claim_amount as integer" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal 260_000_000, result[:claim_amount]
  end

  test "property_count clamps from dlt_dspslGdsDspslObjctLst length" do
    result = @parser.parse_case_search(api_data: @api_data)
    expected = (@api_data["dlt_dspslGdsDspslObjctLst"] || []).length.clamp(1, 99)
    assert_equal expected, result[:property_count]
  end

  test "property_count defaults to 1 when goods list empty" do
    @api_data["dlt_dspslGdsDspslObjctLst"] = []
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal 1, result[:property_count]
  end

  test "returns nil when dma_csBasInf is missing" do
    @api_data.delete("dma_csBasInf")
    assert_nil @parser.parse_case_search(api_data: @api_data)
  end

  test "returns nil when csNo is blank" do
    @api_data["dma_csBasInf"]["csNo"] = ""
    assert_nil @parser.parse_case_search(api_data: @api_data)
  end
end
