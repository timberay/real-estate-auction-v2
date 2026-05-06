require "test_helper"

class CourtAuctionSearchServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "creates search_results from adapter response" do
    mock_response = {
      items: [
        {
          "srnSaNo" => "2024타경4812",
          "jiwonNm" => "제주지방법원",
          "boCd" => "B000260",
          "printSt" => "제주특별자치도 서귀포시 성산읍",
          "gamevalAmt" => "700374010",
          "minmaePrice" => "240228000",
          "dspslUsgNm" => "기타",
          "mulJinYn" => "Y",
          "yuchalCnt" => "3",
          "maeGiil" => "20260421",
          "mulBigo" => "일괄매각"
        }
      ],
      total_count: 1
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(
      user: @user,
      address: "제주특별자치도 서귀포시 성산읍",
      max_bid_price: 200_000_000
    )

    assert_equal 1, result.count
    assert_nil result.error

    sr = @user.search_results.first
    assert_equal "2024타경4812", sr.case_number
    assert_equal "제주지방법원", sr.court_name
    assert_equal "B000260", sr.court_code
    assert_equal 700_374_010, sr.appraisal_price
    assert_equal 240_228_000, sr.min_bid_price
    assert_equal "진행중", sr.status
    assert_equal 3, sr.failed_bid_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "maps address to region_code and max_bid_price to next price tier" do
    mock_response = { items: [], total_count: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구 역삼동 100",
      max_bid_price: 120_000_000
    )

    assert_equal "11", captured_args[:region_code]
    assert_equal 150_000_000, captured_args[:max_price]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "returns error for unrecognized address" do
    result = CourtAuctionSearchService.call(
      user: @user,
      address: "알수없는주소",
      max_bid_price: 100_000_000
    )

    assert_equal 0, result.count
    assert_kind_of ArgumentError, result.error
  end

  test "replaces existing search_results on new search" do
    @user.search_results.create!(case_number: "OLD001", address: "old")

    mock_response = { items: [ { "srnSaNo" => "NEW001", "mulJinYn" => "Y" } ], total_count: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "제주특별자치도 제주시",
      max_bid_price: 100_000_000
    )

    assert_equal 1, @user.search_results.count
    assert_equal "NEW001", @user.search_results.first.case_number
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "deduplicates multi-property cases and records property_count" do
    mock_response = {
      items: [
        { "srnSaNo" => "2024타경1000", "printSt" => "주소A", "mulJinYn" => "Y" },
        { "srnSaNo" => "2024타경1000", "printSt" => "주소B", "mulJinYn" => "Y" },
        { "srnSaNo" => "2024타경2000", "printSt" => "주소C", "mulJinYn" => "Y" }
      ],
      total_count: 3
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 300_000_000
    )

    assert_equal 2, @user.search_results.count
    multi = @user.search_results.find_by(case_number: "2024타경1000")
    single = @user.search_results.find_by(case_number: "2024타경2000")
    assert_equal 2, multi.property_count
    assert_equal 1, single.property_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "captures DataProvider errors" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 100_000_000
    )

    assert_equal 0, result.count
    assert_instance_of DataProvider::TimeoutError, result.error
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "updates user.last_search_api_total_count with API total" do
    mock_response = {
      items: [ { "srnSaNo" => "X1", "mulJinYn" => "Y" } ],
      total_count: 150
    }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 100_000_000
    )

    assert_equal 150, @user.reload.last_search_api_total_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "passes max_items to adapter" do
    captured_args = nil
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      { items: [], total_count: 0 }
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 100_000_000
    )

    assert_equal CourtAuctionSearchService::MAX_ITEMS, captured_args[:max_items]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "does not update user when address is unrecognized" do
    @user.update!(last_search_api_total_count: 42)

    CourtAuctionSearchService.call(
      user: @user,
      address: "알수없는주소",
      max_bid_price: 100_000_000
    )

    assert_equal 42, @user.reload.last_search_api_total_count
  end
end
