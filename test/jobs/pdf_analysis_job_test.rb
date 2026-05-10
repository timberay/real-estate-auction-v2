require "test_helper"

class PdfAnalysisJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    ENV["USE_MOCK"] = "true"
    @user = users(:guest)
    # Mock LLM returns case_number "2024타경12345"; property must match to pass mismatch check
    @property = Property.create!(case_number: "2024타경12345")
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @property.documents.attach(pdf_blob)
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "performs analysis via PdfAnalysisService" do
    initial_count = InspectionResult.count
    PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
    assert InspectionResult.count > initial_count, "Expected InspectionResult count to increase"
  end

  test "broadcasts completion toast to user notifications channel" do
    assert_broadcasts("user_notifications_#{@user.id}", 2) do
      PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
    end
  end

  test "broadcasts failure toast on exception" do
    assert_broadcasts("user_notifications_#{users(:guest).id}", 2) do
      PdfAnalysisJob.perform_now(property_id: -1, user_id: users(:guest).id)
    end
  end

  # --- New tests for retry/discard policy ---

  test "discards JSON::ParserError without retry and broadcasts failure" do
    with_service_raising(JSON::ParserError, "bad json") do
      assert_broadcasts("user_notifications_#{@user.id}", 2) do
        PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
      end
    end
  end

  test "discards CaseNumberMismatchError without retry and broadcasts failure" do
    with_service_raising(PdfAnalysisService::CaseNumberMismatchError, "사건번호 불일치") do
      assert_broadcasts("user_notifications_#{@user.id}", 2) do
        PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
      end
    end
  end

  test "discards CaseNumberMissingError without retry and broadcasts failure" do
    with_service_raising(PdfAnalysisService::CaseNumberMissingError, "사건번호 없음") do
      assert_broadcasts("user_notifications_#{@user.id}", 2) do
        PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
      end
    end
  end

  test "retry_on Faraday::TimeoutError is declared" do
    timeout_handler = PdfAnalysisJob.rescue_handlers.find do |klass, _|
      klass == "Faraday::TimeoutError"
    end
    assert timeout_handler, "Expected retry_on Faraday::TimeoutError to be declared"
  end

  test "retry_on ActiveRecord::ConnectionTimeoutError is declared" do
    db_timeout_handler = PdfAnalysisJob.rescue_handlers.find do |klass, _|
      klass == "ActiveRecord::ConnectionTimeoutError"
    end
    assert db_timeout_handler, "Expected retry_on ActiveRecord::ConnectionTimeoutError to be declared"
  end

  private

  # Temporarily replaces PdfAnalysisService.call with a version that raises
  # the given exception class and message, then restores the original.
  def with_service_raising(error_class, message, &block)
    original = PdfAnalysisService.method(:call)
    PdfAnalysisService.define_singleton_method(:call) { |**| raise error_class, message }
    block.call
  ensure
    PdfAnalysisService.define_singleton_method(:call, original)
  end
end
