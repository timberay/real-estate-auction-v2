require "test_helper"

class PdfAnalysisJobTest < ActiveSupport::TestCase
  setup do
    ENV["USE_MOCK"] = "true"
    @user = users(:guest)
    @property = properties(:safe_apartment)
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
end
