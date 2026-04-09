module CourtAuction
  class BrowserClient
    SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on"
    API_ENDPOINT = "/pgj/pgjsearch/searchControllerMain.on"
    DEFAULT_TIMEOUT = ENV.fetch("BROWSER_TIMEOUT", 30).to_i

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    def fetch(year:, type:, number:)
      browser = nil

      begin
        browser = create_browser
        page = browser.create_page
        setup_response_listener(page)

        page.go_to(SEARCH_URL)
        submit_search(page, year: year, type: type, number: number)
        wait_for_api_response(page)

        body = extract_api_response_body(page)
        JSON.parse(body)
      rescue Ferrum::TimeoutError, Ferrum::ProcessTimeoutError => e
        raise DataProvider::TimeoutError, "Court auction browser timeout: #{e.message}"
      rescue Ferrum::StatusError => e
        raise DataProvider::ServiceUnavailableError, "Court auction site unreachable: #{e.message}"
      rescue JSON::ParserError => e
        raise DataProvider::ParseError, "Invalid JSON from court auction API: #{e.message}"
      ensure
        browser&.quit
      end
    end

    private

    def create_browser
      Ferrum::Browser.new(
        headless: true,
        timeout: @timeout,
        browser_path: ENV["BROWSER_PATH"],
        process_timeout: 10,
        window_size: [ 1280, 720 ]
      )
    rescue Ferrum::BinaryNotFoundError => e
      raise DataProvider::ConfigurationError,
        "Chromium not installed: #{e.message}"
    end

    def setup_response_listener(page)
      @api_response_received = false

      page.on("Network.responseReceived") do |params|
        url = params.dig("response", "url") || ""
        if url.include?(API_ENDPOINT)
          @api_response_received = true
        end
      end
    end

    def submit_search(page, year:, type:, number:)
      page.evaluate(<<~JS)
        (function() {
          var yearInput = document.querySelector('[name="csYr"], [name="srchCsYr"]');
          var typeInput = document.querySelector('[name="csCdNm"], [name="srchCsCdNm"]');
          var numberInput = document.querySelector('[name="csNo"], [name="srchCsNo"]');

          if (yearInput) yearInput.value = '#{escape_js(year.to_s)}';
          if (typeInput) typeInput.value = '#{escape_js(type.to_s)}';
          if (numberInput) numberInput.value = '#{escape_js(number.to_s)}';

          var searchBtn = document.querySelector('.btn_search, [onclick*="search"], button[type="submit"]');
          if (searchBtn) searchBtn.click();
        })();
      JS
    end

    def wait_for_api_response(page)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      loop do
        return if @api_response_received

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        if elapsed > @timeout
          raise Ferrum::TimeoutError
        end

        sleep 0.1
      end
    end

    def extract_api_response_body(page)
      # Wait for network to settle so the response body is available
      page.network.wait_for_idle(duration: 0.1, timeout: 5)

      exchange = page.network.traffic.reverse.find do |e|
        e.request&.url&.include?(API_ENDPOINT) && e.response
      end

      raise DataProvider::DataNotFoundError, "API response not found in network traffic" unless exchange

      body = exchange.response.body
      raise DataProvider::DataNotFoundError, "Empty API response body" if body.nil? || body.empty?

      body
    end

    def escape_js(str)
      str.gsub("\\") { "\\\\" }.gsub("'") { "\\'" }
    end
  end
end
