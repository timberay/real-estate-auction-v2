module CourtAuction
  class BaseClient
    BASE_URL = "https://www.courtauction.go.kr"

    def initialize
      @conn = build_connection
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.request :retry,
          max: 2,
          interval: 1,
          backoff_factor: 2,
          retry_statuses: [502, 503, 504]
        f.options.timeout = 30
        f.options.open_timeout = 5
        f.headers["User-Agent"] = "Mozilla/5.0 (compatible)"
        f.headers["Referer"] = "#{BASE_URL}/pgj/index.on"
        f.headers["Accept"] = "application/json"
      end
    end

    def post(path, body)
      response = @conn.post(path, body)
      handle_http_errors(response)
      response.body
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise DataProvider::ConnectionError, "CourtAuction: #{e.message}"
    end

    def handle_http_errors(response)
      case response.status
      when 200 then nil
      when 403
        raise DataProvider::IpBlockedError, "IP blocked by courtauction.go.kr"
      when 429
        raise DataProvider::RateLimitError, "Rate limited by courtauction.go.kr"
      when 500..599
        raise DataProvider::ServiceUnavailableError, "courtauction.go.kr server error: #{response.status}"
      else
        raise DataProvider::Error, "courtauction.go.kr unexpected status: #{response.status}"
      end
    end
  end
end
