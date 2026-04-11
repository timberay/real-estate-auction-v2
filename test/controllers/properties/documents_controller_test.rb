require "test_helper"

class Properties::DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
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
