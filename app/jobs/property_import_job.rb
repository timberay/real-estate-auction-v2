class PropertyImportJob < ApplicationJob
  queue_as :default

  def perform(user_id:, batch_token:, raw_input:)
    user = User.find(user_id)
    service = Properties::BulkImportService.new(user: user, raw_input: raw_input)
    rows, truncated_count = service.parsed_rows_with_truncation
    total = rows.size
    succeeded = 0
    failed = 0

    rows.each do |row|
      processed = service.process(row)
      if processed.error_message.present?
        failed += 1
      else
        succeeded += 1
      end
      broadcast_row(user, batch_token, processed)
    end

    broadcast_summary(user, batch_token, succeeded: succeeded, failed: failed, truncated: truncated_count, total: total)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn({
      event: "property_import_job.user_not_found",
      job_id: job_id,
      arguments: { user_id: user_id, batch_token: batch_token },
      error_class: e.class.name,
      error_message: e.message
    }.to_json)
  end

  private

  def channel_name(user)
    "user_#{user.id}_bulk_imports"
  end

  def broadcast_row(user, batch_token, row)
    Turbo::StreamsChannel.broadcast_append_to(
      channel_name(user),
      target: "bulk_import_#{batch_token}_rows",
      partial: "properties/bulk_imports/row",
      locals: { row: row }
    )
  rescue => e
    Rails.logger.error "[PropertyImportJob] row broadcast failed: #{e.message}"
  end

  def broadcast_summary(user, batch_token, succeeded:, failed:, truncated:, total:)
    Turbo::StreamsChannel.broadcast_replace_to(
      channel_name(user),
      target: "bulk_import_#{batch_token}_summary",
      partial: "properties/bulk_imports/summary",
      locals: {
        batch_token: batch_token,
        succeeded: succeeded,
        failed: failed,
        truncated: truncated,
        total: total
      }
    )
  rescue => e
    Rails.logger.error "[PropertyImportJob] summary broadcast failed: #{e.message}"
  end
end
