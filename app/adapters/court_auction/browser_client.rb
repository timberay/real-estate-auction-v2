module CourtAuction
  class BrowserClient
    SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on"
    DETAIL_SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"
    API_ENDPOINT = "/pgj/pgjsearch/searchControllerMain.on"
    DETAIL_API_ENDPOINT = "/pgj/pgj15B/selectAuctnCsSrchRslt.on"
    DEFAULT_TIMEOUT = ENV.fetch("BROWSER_TIMEOUT", 30).to_i

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    def fetch(year:, type:, number:)
      with_browser do |page|
        setup_response_listener(page, API_ENDPOINT)

        page.go_to(SEARCH_URL)
        submit_search(page, year: year, type: type, number: number)
        wait_for_api_response(page)

        body = extract_api_response_body(page, API_ENDPOINT)
        JSON.parse(body)
      end
    end

    def fetch_with_detail(year:, type:, number:)
      with_browser do |page|
        # Step 1: Navigate to detail search page and search by case number
        page.go_to(DETAIL_SEARCH_URL)
        sleep 1

        submit_detail_search(page, year: year, number: number)
        setup_response_listener(page, API_ENDPOINT)
        click_search_button(page)
        wait_for_api_response(page)

        search_body = extract_api_response_body(page, API_ENDPOINT)
        search_data = JSON.parse(search_body)

        # Step 2: Click the first result to load detail page
        @api_response_received = false
        setup_response_listener(page, DETAIL_API_ENDPOINT)
        click_first_result(page)
        wait_for_api_response(page)

        detail_body = extract_api_response_body(page, DETAIL_API_ENDPOINT)
        detail_data = JSON.parse(detail_body)

        { "search" => search_data, "detail" => detail_data }
      end
    end

    private

    def with_browser
      browser = nil
      begin
        browser = create_browser
        page = browser.create_page
        yield(page)
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

    def setup_response_listener(page, endpoint)
      @api_response_received = false

      page.on("Network.responseReceived") do |params|
        url = params.dig("response", "url") || ""
        if url.include?(endpoint)
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

    def submit_detail_search(page, year:, number:)
      page.evaluate(<<~JS)
        (function() {
          var yearSelect = document.getElementById('mf_wfm_mainFrame_sbx_rletCsYear');
          if (yearSelect) {
            yearSelect.value = '#{escape_js(year.to_s)}';
            yearSelect.dispatchEvent(new Event('change', {bubbles: true}));
          }
          var numInput = document.querySelector('input[id*="rletCsNo"]');
          if (numInput) {
            numInput.value = '#{escape_js(number.to_s)}';
            numInput.dispatchEvent(new Event('input', {bubbles: true}));
          }
        })();
      JS
      sleep 0.3
    end

    def click_search_button(page)
      page.evaluate(<<~JS)
        (function() {
          var btns = document.querySelectorAll('input[type="button"]');
          for (var i = 0; i < btns.length; i++) {
            if (btns[i].value === '검색' && btns[i].title && btns[i].title.indexOf('물건상세') >= 0) {
              btns[i].click();
              return;
            }
          }
        })();
      JS
    end

    def click_first_result(page)
      sleep 1
      page.evaluate(<<~JS)
        (function() {
          var links = document.querySelectorAll('a');
          for (var i = 0; i < links.length; i++) {
            var text = links[i].textContent || '';
            var parent = links[i].closest('td, div');
            if (parent && parent.className && parent.className.indexOf('printSt') >= 0) {
              links[i].click();
              return;
            }
          }
          // Fallback: click first link that looks like an address
          for (var i = 0; i < links.length; i++) {
            var text = links[i].textContent || '';
            if (text.indexOf('시') >= 0 && text.indexOf('구') >= 0 && text.length > 10) {
              links[i].click();
              return;
            }
          }
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

    def extract_api_response_body(page, endpoint)
      page.network.wait_for_idle(duration: 0.5, timeout: 10)

      exchange = page.network.traffic.reverse.find do |e|
        e.request&.url&.include?(endpoint) && e.response
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
