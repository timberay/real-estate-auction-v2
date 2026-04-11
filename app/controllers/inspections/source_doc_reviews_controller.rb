module Inspections
  class SourceDocReviewsController < ApplicationController
    def update
      property = Property.find(params[:property_id])
      report = RightsAnalysisReport.find_by!(property: property, user: current_user)
      report.update!(source_doc_reviewed: true, user_confirmed_at: Time.current)

      head :ok
    end
  end
end
