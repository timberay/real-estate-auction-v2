require "test_helper"

class PropertyDocumentsTest < ActiveSupport::TestCase
  test "accepts PDF attachments" do
    property = properties(:safe_apartment)
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test content"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    property.documents.attach(pdf_blob)

    assert property.valid?
    assert_equal 1, property.documents.count
  end

  test "rejects non-PDF attachments" do
    property = properties(:safe_apartment)
    txt_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("hello"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    property.documents.attach(txt_blob)

    assert_not property.valid?
    assert_includes property.errors[:documents], "PDF 파일만 업로드할 수 있습니다."
  end
end
