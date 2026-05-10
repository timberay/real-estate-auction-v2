class PdfAnalysisJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, attempts: 3, wait: :polynomially_longer do |job, error|
    user_id = job.arguments.first&.dig(:user_id)
    Rails.logger.error({
      event: "pdf_analysis_job.timeout_exhausted",
      job_id: job.job_id,
      arguments: { user_id: user_id },
      error_class: error.class.name,
      error_message: error.message
    }.to_json)
    job.send(:broadcast_failure_for_user, user_id, "AI 서버가 응답하지 않습니다. 잠시 후 다시 시도해주세요.")
  end

  retry_on ActiveRecord::ConnectionTimeoutError, attempts: 5, wait: 1.minute do |job, error|
    user_id = job.arguments.first&.dig(:user_id)
    Rails.logger.error({
      event: "pdf_analysis_job.db_connection_exhausted",
      job_id: job.job_id,
      arguments: { user_id: user_id },
      error_class: error.class.name,
      error_message: error.message
    }.to_json)
    job.send(:broadcast_failure_for_user, user_id, "데이터베이스 연결 오류로 분석이 실패했습니다. 다시 시도해주세요.")
  end

  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error({
      event: "pdf_analysis_job.deserialization_discard",
      job_id: job.job_id,
      error_class: error.class.name,
      error_message: error.message
    }.to_json)
  end

  discard_on(
    JSON::ParserError,
    PdfAnalysisService::CaseNumberMismatchError,
    PdfAnalysisService::CaseNumberMissingError
  ) do |job, error|
    user_id = job.arguments.first&.dig(:user_id)
    Rails.logger.warn({
      event: "pdf_analysis_job.data_error_discard",
      job_id: job.job_id,
      arguments: { user_id: user_id },
      error_class: error.class.name,
      error_message: error.message
    }.to_json)
    job.send(:broadcast_failure_for_user, user_id, error.message)
  end

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
      broadcast_failure(result.error)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn({
      event: "pdf_analysis_job.record_not_found",
      job_id: job_id,
      arguments: { property_id:, user_id:, document_blob_ids: },
      error_class: e.class.name,
      error_message: e.message
    }.to_json)
    broadcast_failure("요청한 자료를 찾을 수 없습니다.")
  rescue JSON::ParserError,
         PdfAnalysisService::CaseNumberMismatchError,
         PdfAnalysisService::CaseNumberMissingError,
         Faraday::TimeoutError,
         ActiveRecord::ConnectionTimeoutError
    raise
  rescue => e
    Rails.logger.error({
      event: "pdf_analysis_job.unexpected_error",
      job_id: job_id,
      arguments: { property_id:, user_id:, document_blob_ids: },
      error_class: e.class.name,
      error_message: e.message
    }.to_json)
    broadcast_failure("분석 중 오류가 발생했습니다: #{e.message}")
  end

  private

  def broadcast_failure(message)
    broadcast_toast(message, :danger)
    broadcast_indicator(active: false)
  end

  # Called from retry_on/discard_on class-level blocks where @user is not set.
  # Looks up the user by id from the job arguments to obtain the channel name.
  def broadcast_failure_for_user(user_id, message)
    return unless user_id

    @user = User.find_by(id: user_id)
    return unless @user

    broadcast_failure(message)
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] broadcast_failure_for_user failed: #{e.message}"
  end

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
