require "test_helper"

class CourtAuctionSearchServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @user.create_budget_setting!(
      region: "제주특별자치도",
      max_bid_amount: 30000,
      available_cash: 10000
    ) unless @user.budget_setting
  end

  test "creates search_results from adapter response" do
    mock_response = {
      items: [
        {
          "srnSaNo" => "2024타경4812",
          "jiwonNm" => "제주지방법원",
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
      total: 1
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(user: @user)

    assert_equal 1, result.count
    assert_equal 1, @user.search_results.count

    sr = @user.search_results.first
    assert_equal "2024타경4812", sr.case_number
    assert_equal "제주지방법원", sr.court_name
    assert_equal 700_374_010, sr.appraisal_price
    assert_equal 240_228_000, sr.min_bid_price
    assert_equal "진행중", sr.status
    assert_equal 3, sr.failed_bid_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "replaces existing search_results on new search" do
    @user.search_results.create!(case_number: "OLD001", address: "old")

    mock_response = { items: [ { "srnSaNo" => "NEW001", "mulJinYn" => "Y" } ], total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal 1, @user.search_results.count
    assert_equal "NEW001", @user.search_results.first.case_number
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "uses default region when budget_setting has no region" do
    @user.budget_setting.update!(region: nil)

    mock_response = { items: [], total: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal "제주특별자치도", captured_args[:region]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "uses default max_price when budget_setting has no max_bid_amount" do
    @user.budget_setting.update!(max_bid_amount: nil)

    mock_response = { items: [], total: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal 500_000_000, captured_args[:max_price]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "captures DataProvider errors" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(user: @user)

    assert_equal 0, result.count
    assert_instance_of DataProvider::TimeoutError, result.error
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
