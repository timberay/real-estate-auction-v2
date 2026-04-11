class PdfAnalysisJob < ApplicationJob
  queue_as :default

  def perform(property_id: nil, user_id:, document_blob_ids: nil)
    @user = User.find(user_id)
    @property = Property.find(property_id) if property_id

    broadcast_progress("analyzing", "AI 분석 중...")

    result = if document_blob_ids
      documents = ActiveStorage::Blob.where(id: document_blob_ids).to_a
      PdfAnalysisService.call(documents: documents, user: @user)
    else
      PdfAnalysisService.call(property: @property, user: @user)
    end

    if result.success?
      @property = result.property
      broadcast_progress("saving", "결과 저장 중...")
      broadcast_progress("completed", "분석 완료", property_id: result.property.id)
    else
      broadcast_progress("failed", result.error)
    end
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
    broadcast_progress("failed", "분석 중 오류가 발생했습니다: #{e.message}")
  end

  private

  def broadcast_progress(status, message, **extra)
    Turbo::StreamsChannel.broadcast_replace_to(
      "analysis_progress_#{@user.id}",
      target: "analysis_progress",
      partial: "analyses/progress",
      locals: { status: status, message: message, **extra }
    )
  rescue ActionView::MissingTemplate => e
    Rails.logger.debug "[PdfAnalysisJob] Broadcast skipped (template missing): #{e.message}"
  end
end
