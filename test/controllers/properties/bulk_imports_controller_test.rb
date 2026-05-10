require "test_helper"

module Properties
  class BulkImportsControllerTest < ActionDispatch::IntegrationTest
    ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

    setup do
      get start_onboarding_url
      @user = inherit_fixture_guest_ownership
      @fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    end

    test "GET /properties/bulk_import requires auth - logged-out user is redirected" do
      delete auth_logout_url
      get bulk_import_properties_url
      assert_redirected_to auth_login_url
    end

    test "GET /properties/bulk_import succeeds for logged-in user" do
      get bulk_import_properties_url
      assert_response :success
      assert_nil assigns(:result)
    end

    test "GET /properties/bulk_import renders accessible labels for textarea and file inputs" do
      get bulk_import_properties_url
      assert_response :success
      assert_select "label[for=bulk_input]"
      assert_select "label[for=csv_file]"
    end

    test "POST /properties/bulk_import with valid input returns 200 and renders success count" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      post bulk_import_properties_url, params: { bulk_input: "제주지방법원,2022타경564" }

      assert_response :ok
      assert assigns(:result).succeeded.any?
    end

    test "POST /properties/bulk_import with file upload reads CSV content and processes it" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      csv_content = "제주지방법원,2022타경564\n"
      csv_file = Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        "text/csv",
        original_filename: "cases.csv"
      )

      post bulk_import_properties_url, params: { csv_file: csv_file }

      assert_response :ok
      assert assigns(:result).succeeded.any?
    end

    test "POST /properties/bulk_import with all-invalid input returns 422" do
      post bulk_import_properties_url, params: { bulk_input: "잘못된줄\n또잘못된줄" }

      assert_response :unprocessable_entity
      result = assigns(:result)
      assert result.failed.any?
      assert result.succeeded.empty?
    end

    test "POST /properties/bulk_import with mixed valid and invalid returns 422" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      input = "제주지방법원,2022타경564\n없는법원,2026타경9999"
      post bulk_import_properties_url, params: { bulk_input: input }

      assert_response :unprocessable_entity
      result = assigns(:result)
      assert_equal 1, result.succeeded.size
      assert_equal 1, result.failed.size
    end

    test "POST /properties/bulk_import with empty input returns 200" do
      post bulk_import_properties_url, params: { bulk_input: "" }

      assert_response :ok
      result = assigns(:result)
      assert result.succeeded.empty?
      assert result.failed.empty?
    end

    test "POST /properties/bulk_import with BOM-prefixed CSV strips BOM and parses correctly" do
      stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

      bom = "\xEF\xBB\xBF".b.force_encoding("UTF-8")
      csv_content = "#{bom}법원,사건번호\n제주지방법원,2022타경564\n"
      csv_file = Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        "text/csv",
        original_filename: "cases_with_bom.csv"
      )

      post bulk_import_properties_url, params: { csv_file: csv_file }

      result = assigns(:result)
      assert_equal 0, result.failed.count { |r| r.error_message&.include?("형식 오류") },
        "BOM-prefixed header should be skipped, not treated as a format error"
      assert result.succeeded.any?
    end
  end
end
