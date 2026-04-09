# test/adapters/court_auction/rate_limiter_test.rb
require "test_helper"

class CourtAuction::RateLimiterTest < ActiveSupport::TestCase
  setup do
    @limiter = CourtAuction::RateLimiter.new
  end

  test "first request passes immediately" do
    assert_nothing_raised { @limiter.throttle }
  end

  test "records request times" do
    @limiter.throttle
    assert_equal 1, @limiter.request_count
  end

  test "raises RateLimitError when max per minute exceeded" do
    limiter = CourtAuction::RateLimiter.new(max_per_minute: 2, min_interval: 0)
    limiter.throttle
    limiter.throttle
    assert_raises(DataProvider::RateLimitError) { limiter.throttle }
  end

  test "constants have correct defaults" do
    assert_equal 0.5, CourtAuction::RateLimiter::DEFAULT_MIN_INTERVAL
    assert_equal 60, CourtAuction::RateLimiter::DEFAULT_MAX_PER_MINUTE
  end
end
