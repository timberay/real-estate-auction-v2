require "test_helper"
require "ostruct"

class CourtAuctionSearchJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  setup do
    @user = users(:guest)
  end

  test "perform calls CourtAuctionSearchService with given user, address, max_bid_price" do
    captured = nil
    original = CourtAuctionSearchService.method(:call)
    CourtAuctionSearchService.define_singleton_method(:call) do |**kwargs|
      captured = kwargs
      OpenStruct.new(error: nil, count: 0)
    end

    CourtAuctionSearchJob.perform_now(
      user_id: @user.id,
      address: "서울특별시",
      max_bid_price: 100_000_000
    )

    assert_equal @user, captured[:user]
    assert_equal "서울특별시", captured[:address]
    assert_equal 100_000_000, captured[:max_bid_price]
  ensure
    CourtAuctionSearchService.define_singleton_method(:call, original)
  end

  test "broadcasts replaced search results to user-scoped stream on success" do
    original = CourtAuctionSearchService.method(:call)
    CourtAuctionSearchService.define_singleton_method(:call) do |**kwargs|
      kwargs[:user].search_results.create!(
        case_number: "2024타경999",
        court_code: "B000210",
        court_name: "서울지법",
        address: "주소",
        appraisal_price: 100_000_000,
        min_bid_price: 80_000_000
      )
      OpenStruct.new(error: nil, count: 1)
    end

    assert_broadcasts("criteria_search_#{@user.id}", 1) do
      CourtAuctionSearchJob.perform_now(
        user_id: @user.id,
        address: "서울특별시",
        max_bid_price: 100_000_000
      )
    end
  ensure
    CourtAuctionSearchService.define_singleton_method(:call, original)
  end

  test "broadcasts error message to user-scoped stream on failure" do
    original = CourtAuctionSearchService.method(:call)
    CourtAuctionSearchService.define_singleton_method(:call) do |**_|
      OpenStruct.new(error: DataProvider::TimeoutError.new("timeout"), count: 0)
    end

    assert_broadcasts("criteria_search_#{@user.id}", 1) do
      CourtAuctionSearchJob.perform_now(
        user_id: @user.id,
        address: "서울특별시",
        max_bid_price: 100_000_000
      )
    end
  ensure
    CourtAuctionSearchService.define_singleton_method(:call, original)
  end

  test "discards job when user has been deleted between enqueue and execution" do
    missing_id = User.maximum(:id).to_i + 9999

    assert_nothing_raised do
      CourtAuctionSearchJob.perform_now(
        user_id: missing_id,
        address: "서울특별시",
        max_bid_price: 100_000_000
      )
    end
  end

  test "limits global concurrency to 1 with court_browser key" do
    job = CourtAuctionSearchJob.new(
      user_id: @user.id,
      address: "서울특별시",
      max_bid_price: 100_000_000
    )

    assert_includes job.concurrency_key, "court_browser",
      "expected concurrency key to include 'court_browser'"
    assert_equal 1, job.concurrency_limit
  end
end
