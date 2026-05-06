module CourtAuction
  class RateLimiter
    DEFAULT_MIN_INTERVAL = ENV.fetch("COURT_AUCTION_MIN_REQUEST_INTERVAL", 0.5).to_f
    DEFAULT_MAX_PER_MINUTE = ENV.fetch("COURT_AUCTION_MAX_REQUESTS_PER_MINUTE", 60).to_i

    attr_reader :request_count

    def initialize(min_interval: DEFAULT_MIN_INTERVAL, max_per_minute: DEFAULT_MAX_PER_MINUTE)
      @min_interval = min_interval
      @max_per_minute = max_per_minute
      @last_request_at = nil
      @request_times = []
      @request_count = 0
    end

    def throttle
      wait_for_interval
      check_per_minute_limit
      record_request
    end

    private

    def wait_for_interval
      return unless @last_request_at
      elapsed = Time.current - @last_request_at
      sleep(@min_interval - elapsed) if elapsed < @min_interval
    end

    def check_per_minute_limit
      cutoff = Time.current - 60
      @request_times.reject! { |t| t < cutoff }
      if @request_times.size >= @max_per_minute
        raise DataProvider::RateLimitError,
          "Court auction rate limit: #{@max_per_minute}/min exceeded"
      end
    end

    def record_request
      @last_request_at = Time.current
      @request_times << Time.current
      @request_count += 1
    end
  end
end
