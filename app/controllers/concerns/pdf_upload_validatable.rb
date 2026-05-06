# Shared PDF upload validation for controllers that accept user-uploaded PDFs.
# Centralizes the rules so every entry point applies the same checks.
#
# Defends against:
#   - Oversized uploads filling disk and inflating LLM cost (5MB cap)
#   - content_type spoofing (e.g. HTML/EXE renamed .pdf with header forged)
#     by inspecting the file's magic bytes
module PdfUploadValidatable
  extend ActiveSupport::Concern

  MAX_PDF_SIZE = 5.megabytes
  PDF_MAGIC = "%PDF-".b.freeze

  private

  # Returns nil when all files are valid, or a Korean error message string
  # describing the first violation. Caller should redirect with the alert.
  def validate_pdf_uploads(files)
    Array(files).each do |file|
      next unless file.respond_to?(:content_type)
      return "PDF 파일만 업로드할 수 있습니다." unless file.content_type == "application/pdf"
      return "PDF 파일은 5MB를 초과할 수 없습니다." if file.size > MAX_PDF_SIZE

      head = file.read(5).to_s.b
      file.rewind if file.respond_to?(:rewind)
      return "PDF 형식이 아닙니다." unless head == PDF_MAGIC
    end
    nil
  end
end
