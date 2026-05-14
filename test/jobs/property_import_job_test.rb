require "test_helper"

class PropertyImportJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @user = users(:guest)
    @batch_token = "test-batch-#{SecureRandom.hex(4)}"
    @fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    @channel = "user_#{@user.id}_bulk_imports"
  end

  test "queues on :default" do
    assert_equal "default", PropertyImportJob.new.queue_name
  end

  test "perform with valid input creates user_property" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    assert_difference "@user.user_properties.count", 1 do
      PropertyImportJob.perform_now(
        user_id: @user.id,
        batch_token: @batch_token,
        raw_input: "제주지방법원,2022타경564"
      )
    end
  end

  test "broadcasts row append to user channel for each processed row" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    messages = capture_broadcasts(@channel) do
      PropertyImportJob.perform_now(
        user_id: @user.id,
        batch_token: @batch_token,
        raw_input: "제주지방법원,2022타경564"
      )
    end

    payload = messages.map(&:to_s).join
    assert_includes payload, "bulk_import_#{@batch_token}_rows",
      "expected row append broadcast targeting bulk_import_#{@batch_token}_rows"
  end

  test "broadcasts summary banner when complete" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    messages = capture_broadcasts(@channel) do
      PropertyImportJob.perform_now(
        user_id: @user.id,
        batch_token: @batch_token,
        raw_input: "제주지방법원,2022타경564"
      )
    end

    payload = messages.map(&:to_s).join
    assert_includes payload, "bulk_import_#{@batch_token}_summary",
      "expected summary broadcast targeting bulk_import_#{@batch_token}_summary"
  end

  test "perform with invalid court broadcasts failure and creates no user_property" do
    messages = nil

    assert_no_difference "@user.user_properties.count" do
      messages = capture_broadcasts(@channel) do
        PropertyImportJob.perform_now(
          user_id: @user.id,
          batch_token: @batch_token,
          raw_input: "없는법원,2026타경9999"
        )
      end
    end

    payload = messages.map(&:to_s).join
    assert_includes payload, "등록되지 않은 법원",
      "expected failure message in broadcast"
  end

  test "perform with mixed valid and invalid input processes both" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    messages = nil

    assert_difference "@user.user_properties.count", 1 do
      messages = capture_broadcasts(@channel) do
        PropertyImportJob.perform_now(
          user_id: @user.id,
          batch_token: @batch_token,
          raw_input: "제주지방법원,2022타경564\n없는법원,2026타경9999"
        )
      end
    end

    payload = messages.map(&:to_s).join
    assert_includes payload, "등록되지 않은 법원"
    assert_includes payload, "bulk_import_#{@batch_token}_summary"
  end

  test "empty input still broadcasts summary" do
    messages = capture_broadcasts(@channel) do
      PropertyImportJob.perform_now(
        user_id: @user.id,
        batch_token: @batch_token,
        raw_input: ""
      )
    end

    payload = messages.map(&:to_s).join
    assert_includes payload, "bulk_import_#{@batch_token}_summary",
      "summary broadcast still happens for empty input"
  end

  test "summary banner reports succeeded and failed counts" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    messages = capture_broadcasts(@channel) do
      PropertyImportJob.perform_now(
        user_id: @user.id,
        batch_token: @batch_token,
        raw_input: "제주지방법원,2022타경564\n없는법원,2026타경9999"
      )
    end

    summary_payload = messages.map(&:to_s).join
    assert_match(/성공.*1/, summary_payload)
    assert_match(/실패.*1/, summary_payload)
  end
end
