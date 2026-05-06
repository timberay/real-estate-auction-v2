require "test_helper"

class Properties::DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "upload PDF document" do
    pdf = fixture_file_upload("test.pdf", "application/pdf")

    assert_difference "@property.documents.count", 1 do
      post property_documents_path(@property), params: { documents: [ pdf ] }
    end

    assert_redirected_to property_path(@property)
  end

  test "reject non-PDF upload" do
    txt = fixture_file_upload("ai_inspection_response.json", "application/json")

    assert_no_difference "@property.documents.count" do
      post property_documents_path(@property), params: { documents: [ txt ] }
    end

    assert_redirected_to property_path(@property)
    assert_equal "PDF 파일만 업로드할 수 있습니다.", flash[:alert]
  end

  test "rejects file larger than 5MB even with PDF content_type" do
    big_pdf = Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-" + ("a" * 5.megabytes)),
      "application/pdf",
      original_filename: "huge.pdf"
    )

    assert_no_difference "@property.documents.count" do
      post property_documents_path(@property), params: { documents: [ big_pdf ] }
    end

    assert_redirected_to property_path(@property)
    assert_match(/5MB/, flash[:alert])
  end

  test "rejects file whose content_type claims PDF but magic bytes don't match" do
    fake_pdf = Rack::Test::UploadedFile.new(
      StringIO.new("<html><body>not a pdf</body></html>"),
      "application/pdf",
      original_filename: "evil.pdf"
    )

    assert_no_difference "@property.documents.count" do
      post property_documents_path(@property), params: { documents: [ fake_pdf ] }
    end

    assert_redirected_to property_path(@property)
    assert_match(/PDF 형식/, flash[:alert])
  end

  test "delete document" do
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @property.documents.attach(pdf_blob)
    attachment = @property.documents.first

    assert_difference "@property.documents.count", -1 do
      delete property_document_path(@property, attachment)
    end

    assert_redirected_to property_path(@property)
  end
end
