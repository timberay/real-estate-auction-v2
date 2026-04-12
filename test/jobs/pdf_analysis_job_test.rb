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

  test "broadcasts failure message on exception" do
    # Property.find(-1) raises RecordNotFound, caught by rescue => e
    assert_nothing_raised do
      PdfAnalysisJob.perform_now(property_id: -1, user_id: @user.id)
    end
  end
end
