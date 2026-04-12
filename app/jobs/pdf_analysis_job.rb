class PdfAnalysisJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, wait: 5.seconds, attempts: 2
  discard_on ActiveJob::DeserializationError

  def perform(property_id: nil, user_id:, document_blob_ids: nil)
    @user = User.find(user_id)
    @property = Property.find(property_id) if property_id

    broadcast_progress("analyzing", "AI 분석 중... (문서가 많으면 수 분 소요)")

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
  rescue Faraday::TimeoutError => e
    Rails.logger.error "[PdfAnalysisJob] Timeout: #{e.message}"
    broadcast_progress("failed", "AI 서버 응답 시간이 초과되었습니다. 자동 재시도됩니다.")
    raise
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
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Broadcast failed: #{e.message}"
  end
end
