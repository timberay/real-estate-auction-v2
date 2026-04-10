class AiInspectionJob < ApplicationJob
  queue_as :default

  def perform(property)
    AiInspectionRunner.call(property: property, user: nil)
  rescue => e
    Rails.logger.error "[AiInspectionJob] Failed for property #{property.case_number}: #{e.message}"
  end
end
