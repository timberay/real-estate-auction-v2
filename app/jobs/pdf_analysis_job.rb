class PdfAnalysisJob < ApplicationJob
  queue_as :default

  RETRY_WAIT = ENV.fetch("PDF_ANALYSIS_RETRY_WAIT_SECONDS", 5).to_i.seconds
  RETRY_ATTEMPTS = ENV.fetch("PDF_ANALYSIS_RETRY_ATTEMPTS", 2).to_i

  retry_on Faraday::TimeoutError, wait: RETRY_WAIT, attempts: RETRY_ATTEMPTS
  discard_on ActiveJob::DeserializationError

  def perform(property_id: nil, user_id:, document_blob_ids: nil)
    @user = User.find(user_id)
    @property = Property.find(property_id) if property_id

    result = if document_blob_ids
      documents = ActiveStorage::Blob.where(id: document_blob_ids).to_a
      PdfAnalysisService.call(property: @property, documents: documents, user: @user)
    else
      PdfAnalysisService.call(property: @property, user: @user)
    end

    if result.success?
      @property = result.property
      broadcast_toast("분석 완료", :success,
        action_url: inspect_tab_url(result.property.id),
        action_label: "결과 보기")
      broadcast_indicator(active: false)
    else
      broadcast_toast(result.error, :danger)
      broadcast_indicator(active: false)
    end
  rescue Faraday::TimeoutError => e
    Rails.logger.error "[PdfAnalysisJob] Timeout: #{e.message}"
    broadcast_toast("AI 서버 응답 시간이 초과되었습니다. 자동 재시도됩니다.", :danger)
    broadcast_indicator(active: false)
    raise
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
    broadcast_toast("분석 중 오류가 발생했습니다: #{e.message}", :danger)
    broadcast_indicator(active: false)
  end

  private

  def channel_name
    "user_notifications_#{@user.id}"
  end

  def broadcast_toast(message, type, action_url: nil, action_label: nil)
    Turbo::StreamsChannel.broadcast_append_to(
      channel_name,
      target: "global_toasts",
      partial: "notifications/toast",
      locals: { message: message, type: type, action_url: action_url, action_label: action_label }
    )
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Toast broadcast failed: #{e.message}"
  end

  def broadcast_indicator(active:)
    Turbo::StreamsChannel.broadcast_replace_to(
      channel_name,
      target: "analysis_indicator",
      partial: "notifications/analysis_indicator",
      locals: { active: active }
    )
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Indicator broadcast failed: #{e.message}"
  end

  def inspect_tab_url(property_id)
    Rails.application.routes.url_helpers.edit_property_inspections_tab_path(
      property_id, tab_key: "rights_analysis"
    )
  end
end
