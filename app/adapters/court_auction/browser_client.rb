module CourtAuction
  class BrowserClient
    SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"
    API_ENDPOINT = "pgjsearch/searchControllerMain.on"
    DETAIL_API_ENDPOINT = "pgj15B/selectAuctnCsSrchRslt.on"
    DEFAULT_TIMEOUT = ENV.fetch("BROWSER_TIMEOUT", 60).to_i
    PAGE_LOAD_WAIT = 3

    # WebSquare element IDs
    YEAR_SELECT = "mf_wfm_mainFrame_sbx_rletCsYear"
    CASE_NUMBER_INPUT = "mf_wfm_mainFrame_ibx_rletCsNo"
    REGION_RADIO = "mf_wfm_mainFrame_rad_rletSrchBtn_input_2"
    REGION_SELECT = "mf_wfm_mainFrame_sbx_rletAdongSdR"
    USAGE_LARGE_SELECT = "mf_wfm_mainFrame_sbx_rletLclLst"
    USAGE_MID_SELECT = "mf_wfm_mainFrame_sbx_rletMclLst"
    MIN_PRICE_SELECT = "mf_wfm_mainFrame_sbx_rletLwsDspslMin"
    MAX_PRICE_SELECT = "mf_wfm_mainFrame_sbx_rletLwsDspslMax"
    SEARCH_BUTTON = "mf_wfm_mainFrame_btn_gdsDtlSrch"

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    def fetch_with_detail(year:, type:, number:)
      with_browser do |page|
        navigate_to_search(page)
        fill_case_number(page, year: year, number: number)
        search_data = click_search_and_capture(page)

        items = search_data.dig("data", "dlt_srchResult") || []
        match = find_matching_item(items, year: year, type: type, number: number)
        raise DataProvider::DataNotFoundError, "Case #{year}#{type}#{number} not found" unless match

        detail_data = click_result_and_capture_detail(page, match)

        { "search" => search_data, "detail" => detail_data }
      end
    end

    def search_by_criteria(region:, year:, min_price:, max_price:)
      with_browser do |page|
        navigate_to_search(page)
        fill_criteria(page, region: region, year: year, min_price: min_price, max_price: max_price)
        search_data = click_search_and_capture(page)

        items = search_data.dig("data", "dlt_srchResult") || []
        total = search_data.dig("data", "dma_pageInfo", "totalCnt").to_i

        { items: items, total: total }
      end
    end

    private

    def with_browser
      execution = nil
      browser = nil
      begin
        execution = Playwright.create(playwright_cli_executable_path: find_playwright_cli)
        browser = execution.playwright.chromium.launch(headless: true)
        page = browser.new_page
        yield(page)
      rescue Playwright::TimeoutError => e
        raise DataProvider::TimeoutError, "Court auction browser timeout: #{e.message}"
      rescue JSON::ParserError => e
        raise DataProvider::ParseError, "Invalid JSON from court auction API: #{e.message}"
      ensure
        browser&.close
        execution&.stop
      end
    end

    def find_playwright_cli
      ENV["PLAYWRIGHT_CLI_PATH"] || "npx playwright"
    end

    def navigate_to_search(page)
      page.goto(SEARCH_URL, wait_until: "networkidle", timeout: @timeout * 1000)
      page.wait_for_timeout(PAGE_LOAD_WAIT * 1000)
    rescue Playwright::Error => e
      raise DataProvider::ServiceUnavailableError, "Court auction site unreachable: #{e.message}"
    end

    def fill_case_number(page, year:, number:)
      set_select_via_js(page, YEAR_SELECT, year.to_s)
      raw_number = number.to_s.gsub(/\A0+/, "")
      page.fill("##{CASE_NUMBER_INPUT}", raw_number)
      page.wait_for_timeout(500)
    end

    def fill_criteria(page, region:, year:, min_price:, max_price:)
      # 1. Click "소재지(새주소)" radio
      page.click("##{REGION_RADIO}")
      page.wait_for_timeout(500)

      # 2. Set region via DOM dispatchEvent (for cascade)
      set_select_via_dom(page, REGION_SELECT, region)
      page.wait_for_timeout(500)

      # 3. Set year
      set_select_via_js(page, YEAR_SELECT, year.to_s)

      # 4. Set usage: 건물 → 주거용건물 (cascade)
      set_select_via_dom(page, USAGE_LARGE_SELECT, "건물")
      page.wait_for_timeout(1500) # wait for mid-category options to load
      set_select_via_dom(page, USAGE_MID_SELECT, "주거용건물")
      page.wait_for_timeout(300)

      # 5. Set price range
      set_select_via_dom(page, MIN_PRICE_SELECT, price_label(50_000_000))
      set_select_via_dom(page, MAX_PRICE_SELECT, price_label(max_price))
      page.wait_for_timeout(300)
    end

    def click_search_and_capture(page)
      response = page.expect_response(
        ->(resp) { resp.url.include?(API_ENDPOINT) && resp.status == 200 },
        timeout: @timeout * 1000
      ) do
        page.evaluate("WebSquare.util.getComponentById('#{SEARCH_BUTTON}').trigger('onclick');")
      end

      JSON.parse(response.body)
    end

    def click_result_and_capture_detail(page, match)
      address = match["printSt"].to_s
      keyword = address.split(/\s+/).find { |w| w.length > 2 } || address[0..10]

      page.wait_for_timeout(1000) # let DOM render

      response = page.expect_response(
        ->(resp) { resp.url.include?(DETAIL_API_ENDPOINT) && resp.status == 200 },
        timeout: @timeout * 1000
      ) do
        page.evaluate(<<~JS)
          (function() {
            var keyword = '#{escape_js(keyword)}';
            var links = document.querySelectorAll('a');
            for (var i = 0; i < links.length; i++) {
              var text = (links[i].textContent || '').trim();
              if (text.indexOf(keyword) >= 0 && text.length > 10) {
                links[i].click();
                return;
              }
            }
          })();
        JS
      end

      JSON.parse(response.body)
    end

    def find_matching_item(items, year:, type:, number:)
      num_str = number.to_s
      candidates = [
        "#{year}#{type}#{num_str}",
        "#{year}#{type}#{num_str.rjust(5, '0')}",
        "#{year}#{type}#{num_str.gsub(/\A0+/, '')}"
      ].uniq
      items.find { |i| candidates.include?(i["srnSaNo"]) }
    end

    def set_select_via_js(page, element_id, value)
      page.evaluate("WebSquare.util.getComponentById('#{element_id}').setValue('#{escape_js(value)}');")
    end

    def set_select_via_dom(page, element_id, value)
      page.evaluate(<<~JS)
        (function() {
          var el = document.getElementById('#{element_id}');
          if (el) {
            el.value = '#{escape_js(value)}';
            el.dispatchEvent(new Event('change', {bubbles: true}));
          }
        })();
      JS
    end

    def price_label(won)
      case won
      when 10_000_000 then "1천만원"
      when 50_000_000 then "5천만원"
      when 1_000_000_000 then "10억원"
      else
        eok = won / 100_000_000
        remainder = (won % 100_000_000) / 10_000_000
        if eok > 0 && remainder > 0
          "#{eok}억#{remainder}천만원"
        elsif eok > 0
          "#{eok}억원"
        else
          "#{won / 10_000_000}천만원"
        end
      end
    end

    def escape_js(str)
      str.to_s.gsub("\\") { "\\\\" }.gsub("'") { "\\'" }
    end
  end
end
