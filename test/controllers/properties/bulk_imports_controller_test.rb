require "test_helper"

module Properties
  class BulkImportsControllerTest < ActionDispatch::IntegrationTest
    setup do
      get start_onboarding_url
      @user = inherit_fixture_guest_ownership
    end

    test "GET /properties/bulk_import requires auth - logged-out user is redirected" do
      delete auth_logout_url
      get bulk_import_properties_url
      assert_redirected_to auth_login_url
    end

    test "GET /properties/bulk_import succeeds for logged-in user" do
      get bulk_import_properties_url
      assert_response :success
      assert_nil assigns(:batch_token)
    end

    test "GET /properties/bulk_import renders accessible labels for textarea and file inputs" do
      get bulk_import_properties_url
      assert_response :success
      assert_select "label[for=bulk_input]"
      assert_select "label[for=csv_file]"
    end

    test "POST /properties/bulk_import with valid input enqueues PropertyImportJob and returns 202" do
      assert_enqueued_with(job: PropertyImportJob) do
        post bulk_import_properties_url, params: { bulk_input: "제주지방법원,2022타경564" }
      end
      assert_response :accepted
      assert assigns(:batch_token).present?, "expected @batch_token to be assigned"
    end

    test "POST /properties/bulk_import with file upload enqueues job with CSV content" do
      csv_content = "제주지방법원,2022타경564\n"
      csv_file = Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        "text/csv",
        original_filename: "cases.csv"
      )

      assert_enqueued_with(job: PropertyImportJob) do
        post bulk_import_properties_url, params: { csv_file: csv_file }
      end
      assert_response :accepted
    end

    test "POST /properties/bulk_import with all-invalid input still enqueues (job broadcasts failures)" do
      assert_enqueued_with(job: PropertyImportJob) do
        post bulk_import_properties_url, params: { bulk_input: "잘못된줄\n또잘못된줄" }
      end
      assert_response :accepted
    end

    test "POST /properties/bulk_import with empty input does not enqueue and re-renders form" do
      assert_no_enqueued_jobs only: PropertyImportJob do
        post bulk_import_properties_url, params: { bulk_input: "" }
      end
      assert_response :ok
      assert_nil assigns(:batch_token)
    end

    test "POST /properties/bulk_import with BOM-prefixed CSV strips BOM and enqueues" do
      bom = "\xEF\xBB\xBF".b.force_encoding("UTF-8")
      csv_content = "#{bom}법원,사건번호\n제주지방법원,2022타경564\n"
      csv_file = Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        "text/csv",
        original_filename: "cases_with_bom.csv"
      )

      enqueued_args = nil
      assert_enqueued_with(job: PropertyImportJob) do
        post bulk_import_properties_url, params: { csv_file: csv_file }
      end
      enqueued_args = ActiveJob::Base.queue_adapter.enqueued_jobs.last[:args].first
      refute enqueued_args["raw_input"].start_with?(bom),
        "BOM should be stripped before enqueue"
    end

    test "POST renders placeholder div bound to user channel for live updates" do
      post bulk_import_properties_url, params: { bulk_input: "제주지방법원,2022타경564" }
      assert_response :accepted
      token = assigns(:batch_token)
      assert_select "##{"bulk_import_#{token}_rows"}"
      assert_select "##{"bulk_import_#{token}_summary"}"
    end
  end
end
