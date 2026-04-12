class AnalysesController < ApplicationController
  def new
  end

  def create
    uploaded_files = Array(params[:documents]).reject { |f| f.is_a?(String) }

    if uploaded_files.empty?
      redirect_to new_analysis_path, alert: "PDF 파일을 업로드해주세요."
      return
    end

    blob_ids = uploaded_files.map do |file|
      unless file.content_type == "application/pdf"
        redirect_to new_analysis_path, alert: "PDF 파일만 업로드할 수 있습니다."
        return
      end
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type
      ).id
    end

    PdfAnalysisJob.perform_later(
      property_id: nil,
      user_id: current_user.id,
      document_blob_ids: blob_ids
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "analysis_form",
          partial: "analyses/progress",
          locals: { status: "analyzing", message: "AI 분석 중..." }
        )
      end
      format.html do
        redirect_to new_analysis_path, notice: "분석이 시작되었습니다."
      end
    end
  end
end
