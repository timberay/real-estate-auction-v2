module Inspections
  class SourceDocReviewsController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    def update
      report = RightsAnalysisReport.find_by!(property: @property, user: current_user)
      report.update!(source_doc_reviewed: true, user_confirmed_at: Time.current)

      head :ok
    end
  end
end
