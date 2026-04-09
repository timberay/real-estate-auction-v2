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

  test "parse_with_detail merges detail data" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal "부동산임의경매", result[:case_type]
    assert_equal 50_000_000, result[:claim_amount]
    assert_equal "전세권", result[:non_extinguished_rights]
    assert_equal "2021.3.15. 근저당권", result[:senior_mortgage_basis]
    assert_equal "매각 참고사항", result[:specification_remarks]
    assert_equal "비고", result[:goods_remarks]
  end

  test "parse_with_detail normalizes empty rights text" do
    detail_response = build_detail_response(rights_text: "해당사항없음")
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_nil result[:non_extinguished_rights]
  end

  test "parse_with_detail overrides building fields from detail" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal "대지", result[:land_category]
    assert_equal "5층501호", result[:building_detail]
  end

  test "parse_with_detail parses dividend demand deadline" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal Date.new(2026, 7, 1), result[:dividend_demand_deadline]
  end

  test "parse_with_detail parses auction schedules" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal 1, result[:auction_schedules].size
    schedule = result[:auction_schedules].first
    assert_equal Date.new(2026, 5, 1), schedule[:schedule_date]
    assert_equal "1000", schedule[:schedule_time]
    assert_equal "경매법정4별관211호", schedule[:place]
  end

  test "parse_with_detail parses appraisal points" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal 1, result[:appraisal_points].size
    assert_equal "00083001", result[:appraisal_points].first[:item_code]
  end

  test "parse_with_detail parses land details from nested arrays" do
    detail_response = build_detail_response
    result = @parser.parse_with_detail(
      search_response: @fixture,
      detail_response: detail_response
    )

    assert_equal 1, result[:land_details].size
    assert_equal "대지", result[:land_details].first[:land_type]
  end

  private

  def build_detail_response(rights_text: "전세권")
    {
      "data" => {
        "dma_result" => {
          "csBaseInfo" => {
            "csNm" => "부동산임의경매",
            "csRcptYmd" => "20250101",
            "clmAmt" => "50000000"
          },
          "dspslGdsDxdyInfo" => {
            "ndstrcRghCtt" => rights_text,
            "gdsSpcfcRmk" => "매각 참고사항",
            "tprtyRnkHypthcStngDts" => "2021.3.15. 근저당권",
            "dspslGdsRmk" => "비고",
            "tsLwsDspslPrc1" => "800000000",
            "tsLwsDspslPrc2" => "560000000"
          },
          "gdsDspslObjctLst" => [
            {
              "rletDvsDts" => "대지",
              "bldDtlDts" => "5층501호",
              "bldNm" => "테스트아파트",
              "pjbBuldList" => "철근콩크리트조",
              "dspslStkCtt" => ""
            }
          ],
          "dstrtDemnInfo" => [
            { "dstrtDemnLstprdYmd" => "20260701" }
          ],
          "gdsDspslDxdyLst" => [
            {
              "dxdyYmd" => "20260501",
              "dxdyHm" => "1000",
              "dxdyPlcNm" => "경매법정4별관211호",
              "auctnDxdyKndCd" => "01",
              "auctnDxdyRsltCd" => "",
              "tsLwsDspslPrc" => "560000000",
              "dspslAmt" => "0"
            }
          ],
          "rgltLandLstAll" => [
            [
              {
                "rletDvsDts" => "대지",
                "landArea" => "150.00",
                "ldcgCd" => "01",
                "shrRt" => "10000분의 245",
                "printSt" => "서울특별시 강남구 역삼동 100-1",
                "lotNo" => "100-1"
              }
            ]
          ],
          "aeeWevlMnpntLst" => [
            {
              "aeeWevlMnpntItmCd" => "00083001",
              "aeeWevlMnpntCtt" => "역삼역 인근에 위치하며 주위는 아파트단지 및 상가 등이 소재함."
            }
          ]
        }
      }
    }
  end
end
