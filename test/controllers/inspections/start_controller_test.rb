require "test_helper"

class Inspections::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "redirects with alert when no documents attached" do
    post property_inspections_start_url(@property)
    assert_redirected_to property_path(@property)
    assert_equal "분석할 문서를 먼저 업로드해주세요.", flash[:alert]
  end

  test "enqueues PdfAnalysisJob and redirects when documents attached" do
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @property.documents.attach(pdf_blob)

    assert_enqueued_with(job: PdfAnalysisJob) do
      post property_inspections_start_url(@property)
    end
    assert_redirected_to property_path(@property)
    assert_equal "분석이 시작되었습니다.", flash[:notice]
  end

  test "broadcasts analysis indicator on start" do
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @property.documents.attach(pdf_blob)

    assert_broadcasts("user_notifications_#{@user.id}", 1) do
      post property_inspections_start_url(@property)
    end
  end
end
