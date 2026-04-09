require "test_helper"

class CourtAuction::ResponseParserTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    @search_result = {
      court_code: "B001001",
      court_name: "서울중앙지방법원",
      item_number: "001",
      property_type: "아파트",
      address: "서울특별시 강남구 역삼동 100-1",
      appraisal_price: 800_000_000,
      min_bid_price: 560_000_000,
      is_partial_share: false,
      failed_bid_count: 0,
      status: "진행"
    }
    @detail_result = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
  end

  test "parses complete result matching mock adapter schema" do
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
    assert_equal "해당사항 없음", result[:remarks]
    assert_equal [], result[:non_extinguished_rights]
    assert_equal [], result[:tenants]
    assert_equal false, result[:separate_land_registry]
    assert_equal false, result[:lien_reported]
    assert_equal true, result[:use_approval]
    assert_equal false, result[:wall_partition_issue]
    assert_equal false, result[:is_partial_share]
  end

  test "includes new fields not in mock" do
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal 0, result[:failed_bid_count]
    assert_equal "진행", result[:status]
    assert_kind_of Array, result[:sale_schedule]
  end

  test "maps boolean Y/N correctly" do
    @detail_result["lienRptYn"] = "Y"
    @detail_result["useAprYn"] = "N"
    @detail_result["sprtLandRgstYn"] = "Y"
    @detail_result["wlpttIsuYn"] = "Y"

    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal true, result[:lien_reported]
    assert_equal false, result[:use_approval]
    assert_equal true, result[:separate_land_registry]
    assert_equal true, result[:wall_partition_issue]
  end

  test "parses tenants from detail" do
    @detail_result["dlt_tenants"] = [
      {
        "tnntNm" => "김임차",
        "dpstAmt" => "50000000",
        "mvnDt" => "20240315",
        "dvdReqYn" => "N"
      }
    ]
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal 1, result[:tenants].size
    tenant = result[:tenants].first
    assert_equal "김임차", tenant[:name]
    assert_equal 50_000_000, tenant[:deposit]
    assert_equal "2024-03-15", tenant[:move_in_date]
    assert_equal false, tenant[:dividend_requested]
  end

  test "parses non-extinguished rights" do
    @detail_result["dlt_neRghts"] = [
      { "rghtsNm" => "전세권" },
      { "rghtsNm" => "지상권" }
    ]
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal [ "전세권", "지상권" ], result[:non_extinguished_rights]
  end

  test "has all keys that MockCourtAuctionAdapter returns" do
    mock_keys = MockCourtAuctionAdapter.new.fetch_data(case_number: "2026타경10001").keys
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    mock_keys.each do |key|
      assert result.key?(key), "Missing key: #{key}"
    end
  end

  test "raises ParseError when required fields missing" do
    @search_result[:court_name] = nil
    assert_raises(DataProvider::ParseError) do
      @parser.parse(search_result: @search_result, detail_result: @detail_result)
    end
  end
end
