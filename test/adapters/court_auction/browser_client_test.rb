require "test_helper"

class CourtAuction::BrowserClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::BrowserClient.new(timeout: 5)
    @fixture_json = File.read(
      Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json")
    )
  end

  # -- Happy path --------------------------------------------------------

  test "fetch returns parsed JSON when API response is intercepted" do
    with_stubbed_browser(response_body: @fixture_json) do
      result = @client.fetch(year: "2026", type: "타경", number: "10001")

      assert_kind_of Hash, result
      assert_equal 200, result["status"]
      assert result.dig("data", "dlt_srchResult").is_a?(Array)
    end
  end

  # -- Error mapping -----------------------------------------------------

  test "raises TimeoutError on Ferrum::TimeoutError" do
    with_stubbed_browser_new(-> { raise Ferrum::TimeoutError }) do
      error = assert_raises(DataProvider::TimeoutError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
      assert_match(/timeout/i, error.message)
    end
  end

  test "raises TimeoutError on Ferrum::ProcessTimeoutError" do
    with_stubbed_browser_new(-> { raise Ferrum::ProcessTimeoutError.new(10, "") }) do
      error = assert_raises(DataProvider::TimeoutError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
      assert_match(/timeout/i, error.message)
    end
  end

  test "raises ServiceUnavailableError on Ferrum::StatusError" do
    browser = MockBrowser.new
    browser.page = MockPage.new(
      network: MockNetwork.new(nil),
      raise_on_goto: Ferrum::StatusError.new("https://example.com")
    )

    with_stubbed_browser_new(-> { browser }) do
      assert_raises(DataProvider::ServiceUnavailableError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end

    assert browser.quit_called, "browser.quit must be called"
  end

  test "raises ConfigurationError when Chromium binary is not found" do
    with_stubbed_browser_new(-> { raise Ferrum::BinaryNotFoundError }) do
      error = assert_raises(DataProvider::ConfigurationError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
      assert_match(/chromium/i, error.message)
    end
  end

  test "raises ParseError on invalid JSON response body" do
    with_stubbed_browser(response_body: "not json {{{") do
      assert_raises(DataProvider::ParseError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "raises DataNotFoundError when no matching traffic entry" do
    with_stubbed_browser(response_body: nil, empty_traffic: true) do
      assert_raises(DataProvider::DataNotFoundError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  # -- Ensure block ------------------------------------------------------

  test "browser.quit is always called even when an error occurs" do
    browser = MockBrowser.new
    browser.page = MockPage.new(
      network: MockNetwork.new(nil),
      raise_on_evaluate: StandardError.new("boom")
    )

    with_stubbed_browser_new(-> { browser }) do
      assert_raises(StandardError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end

    assert browser.quit_called, "browser.quit must be called in ensure block"
  end

  # -- JS escaping -------------------------------------------------------

  test "escape_js escapes single quotes for safe JS interpolation" do
    escaped = @client.send(:escape_js, "O'Brien")
    assert_equal "O\\'Brien", escaped
  end

  test "escape_js escapes backslashes" do
    escaped = @client.send(:escape_js, 'path\\to')
    assert_equal 'path\\\\to', escaped
  end

  private

  # Stubs Ferrum::Browser.new to return a MockBrowser wired with the given
  # response body, then yields to the test block.
  def with_stubbed_browser(response_body:, empty_traffic: false)
    browser = MockBrowser.new
    browser.page = MockPage.new(
      network: MockNetwork.new(response_body, empty_traffic: empty_traffic)
    )
    with_stubbed_browser_new(-> { browser }) { yield }
  end

  # Stubs Ferrum::Browser.new with a callable that returns (or raises from)
  # the given lambda.
  def with_stubbed_browser_new(factory)
    original = Ferrum::Browser.method(:new)
    Ferrum::Browser.define_singleton_method(:new) { |**_opts| factory.call }
    yield
  ensure
    Ferrum::Browser.define_singleton_method(:new, original)
  end

  # -- Test doubles ------------------------------------------------------

  class MockBrowser
    attr_accessor :page, :quit_called

    def initialize
      @quit_called = false
    end

    def create_page
      page
    end

    def quit
      @quit_called = true
    end
  end

  class MockPage
    attr_reader :network

    def initialize(network:, raise_on_goto: nil, raise_on_evaluate: nil)
      @network = network
      @raise_on_goto = raise_on_goto
      @raise_on_evaluate = raise_on_evaluate
      @listeners = {}
    end

    def on(event_name, &block)
      @listeners[event_name] ||= []
      @listeners[event_name] << block
    end

    def go_to(_url)
      raise @raise_on_goto if @raise_on_goto
      true
    end

    def evaluate(_js)
      raise @raise_on_evaluate if @raise_on_evaluate
      fire_response_received
      true
    end

    private

    def fire_response_received
      api_url = "https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on"
      params = { "response" => { "url" => api_url } }

      (@listeners["Network.responseReceived"] || []).each do |cb|
        cb.call(params)
      end
    end
  end

  class MockNetwork
    attr_reader :traffic

    def initialize(response_body, empty_traffic: false)
      @traffic = if empty_traffic
        []
      else
        api_url = "https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on"
        [ MockExchange.new(api_url, response_body) ]
      end
    end

    def wait_for_idle(duration: 0.05, timeout: 5)
      true
    end
  end

  class MockExchange
    attr_reader :request, :response

    def initialize(url, body)
      @request = MockRequest.new(url)
      @response = body ? MockResponse.new(body) : nil
    end
  end

  class MockRequest
    attr_reader :url
    def initialize(url) = @url = url
  end

  class MockResponse
    def initialize(body) = @body = body
    def body = @body
  end
end
