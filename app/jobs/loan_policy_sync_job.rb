class LoanPolicySyncJob < ApplicationJob
  queue_as :default

  def perform
    result = LoanPolicySyncService.call
    Rails.logger.info "[LoanPolicySyncJob] Synced: #{result[:synced_count]}, Skipped: #{result[:skipped_count]}, Types: #{result[:property_types_processed].join(', ')}"
  end
end
