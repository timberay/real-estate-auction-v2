require "test_helper"

class PdfExportServiceTest < ActiveSupport::TestCase
  test "generates PDF binary from HTML" do
    html = <<~HTML
      <!DOCTYPE html>
      <html><head><style>body { font-family: sans-serif; }</style></head>
      <body><h1>Test PDF</h1><p>Korean text: 테스트 문서</p></body></html>
    HTML

    result = PdfExportService.call(html: html)
    assert result.present?, "PDF binary should not be empty"
    assert result.start_with?("%PDF"), "Output should be a valid PDF"
  end
end
