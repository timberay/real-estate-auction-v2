require "test_helper"

module Properties
  class BulkImportServiceTest < ActiveSupport::TestCase
    ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

    setup do
      @fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
      @user = users(:guest)
    end

    # ------------------------------------------------------------------ #
    # Parser unit tests
    # ------------------------------------------------------------------ #

    test "single comma-separated line parses correctly" do
      rows = parse_input("서울중앙지방법원,2026타경1234")
      assert_equal 1, rows.size
      assert_equal "서울중앙지방법원", rows.first.court_name
      assert_equal "2026타경1234", rows.first.case_number
      assert_nil rows.first.error_message
    end

    test "single tab-separated line parses correctly" do
      rows = parse_input("서울중앙지방법원\t2026타경1234")
      assert_equal 1, rows.size
      assert_equal "서울중앙지방법원", rows.first.court_name
      assert_nil rows.first.error_message
    end

    test "single space-separated line parses correctly" do
      rows = parse_input("서울중앙지방법원 2026타경1234")
      assert_equal 1, rows.size
      assert_equal "2026타경1234", rows.first.case_number
      assert_nil rows.first.error_message
    end

    test "mixed separators across lines all parse without error" do
      input = "서울중앙지방법원,2026타경1234\n서울남부지방법원\t2025타경5678\n서울북부지방법원 2024타경9999"
      rows = parse_input(input)
      assert_equal 3, rows.size
      assert rows.all? { |r| r.error_message.nil? }
    end

    test "blank lines and leading/trailing whitespace are ignored" do
      input = "\n  \n서울중앙지방법원,2026타경1234\n\n   \n"
      rows = parse_input(input)
      assert_equal 1, rows.size
    end

    test "comment lines starting with # are ignored" do
      input = "# 이건 주석입니다\n서울중앙지방법원,2026타경1234"
      rows = parse_input(input)
      assert_equal 1, rows.size
    end

    test "Korean header row 법원,사건번호 is ignored" do
      input = "법원,사건번호\n서울중앙지방법원,2026타경1234"
      rows = parse_input(input)
      assert_equal 1, rows.size
    end

    test "English header row court,case_number is ignored" do
      input = "court,case_number\n서울중앙지방법원,2026타경1234"
      rows = parse_input(input)
      assert_equal 1, rows.size
    end

    test "malformed line with only one field marks row as failed with explicit error" do
      rows = parse_input("서울중앙지방법원")
      assert_equal 1, rows.size
      assert_match "형식 오류", rows.first.error_message
      assert_match "서울중앙지방법원", rows.first.error_message
    end

    test "line where case_number field does not match pattern marks row as failed" do
      rows = parse_input("서울중앙지방법원,두건물A동")
      assert_equal 1, rows.size
      assert_match "형식 오류", rows.first.error_message
    end

    test "input of 60 lines caps at 50, truncated_count is 10" do
      lines = (1..60).map { |i| "서울중앙지방법원,2026타경#{i.to_s.rjust(4, '0')}" }
      service = BulkImportService.new(user: @user, raw_input: lines.join("\n"))

      parsed = service.send(:parse_input)
      assert_equal 60, parsed.size

      stub_all_court_requests_with_not_found
      result = service.call
      assert_equal 10, result.truncated_count
      assert_equal 50, result.total
    end

    # ------------------------------------------------------------------ #
    # Service integration tests
    # ------------------------------------------------------------------ #

    test "happy path: 2 valid lines both succeed, 2 user_properties created" do
      json = JSON.parse(@fixture)
      json["data"]["dma_csBasInf"]["userCsNo"] = "2026타경1234"
      stub1 = json.to_json

      json2 = JSON.parse(@fixture)
      json2["data"]["dma_csBasInf"]["userCsNo"] = "2025타경5678"
      stub2 = json2.to_json

      stub_request(:post, ENDPOINT)
        .to_return({ status: 200, body: stub1 }, { status: 200, body: stub2 })

      input = "제주지방법원,2026타경1234\n제주지방법원,2025타경5678"
      result = nil

      assert_difference "UserProperty.count", 2 do
        result = BulkImportService.call(user: @user, raw_input: input)
      end

      assert_equal 2, result.succeeded.size
      assert_equal 0, result.failed.size
    end

    test "partial: 1 valid + 1 unknown court → 1 succeeded + 1 failed with 등록되지 않은 법원 message" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      input = "제주지방법원,2022타경564\n없는법원,2026타경9999"
      result = BulkImportService.call(user: @user, raw_input: input)

      assert_equal 1, result.succeeded.size
      assert_equal 1, result.failed.size
      assert_match "등록되지 않은 법원", result.failed.first.error_message
      assert_match "없는법원", result.failed.first.error_message
    end

    test "duplicate: same case twice in input → first is new, second is already_existed" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      input = "제주지방법원,2022타경564\n제주지방법원,2022타경564"
      result = BulkImportService.call(user: @user, raw_input: input)

      assert_equal 2, result.succeeded.size
      assert_equal false, result.succeeded[0].already_existed
      assert_equal true,  result.succeeded[1].already_existed
    end

    test "site outage: 503 response marks row failed with localized outage message" do
      stub_request(:post, ENDPOINT).to_return(status: 503)

      result = BulkImportService.call(user: @user, raw_input: "제주지방법원,2026타경1111")

      assert_equal 1, result.failed.size
      assert_match "법원경매 사이트에 접속할 수 없습니다", result.failed.first.error_message
    end

    test "empty input returns empty result with no error raised" do
      result = BulkImportService.call(user: @user, raw_input: "")
      assert result.succeeded.empty?
      assert result.failed.empty?
      assert_equal 0, result.truncated_count
    end

    test "타채 case number pattern is accepted" do
      rows = parse_input("서울중앙지방법원,2026타채0001")
      assert_equal 1, rows.size
      assert_nil rows.first.error_message
      assert_equal "2026타채0001", rows.first.case_number
    end

    private

    def parse_input(input)
      BulkImportService.new(user: @user, raw_input: input).send(:parse_input)
    end

    def call_service(input)
      stub_all_court_requests_with_not_found
      BulkImportService.call(user: @user, raw_input: input)
    end

    def stub_all_court_requests_with_not_found
      stub_request(:post, ENDPOINT)
        .to_return(status: 200, body: { "data" => { "dma_csBasInf" => { "csNo" => "" } } }.to_json)
    end
  end
end
