# Shared PDF upload validation for controllers that accept user-uploaded PDFs.
# Centralizes the rules so every entry point applies the same checks.
module PdfUploadValidatable
  extend ActiveSupport::Concern

  private

  # Returns nil when all files are valid, or a Korean error message string
  # describing the first violation. Caller should redirect with the alert.
  def validate_pdf_uploads(files)
    Array(files).each do |file|
      next unless file.respond_to?(:content_type)
      return "PDF 파일만 업로드할 수 있습니다." unless file.content_type == "application/pdf"
    end
    nil
  end
end
