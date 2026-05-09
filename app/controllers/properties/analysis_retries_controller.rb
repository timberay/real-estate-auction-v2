module Properties
  # Re-runs PDF analysis for a property whose previous run ended in
  # extraction_failed (or any other transient failure). Surfaces a retry
  # button on the failure UI; scoped to current_user via PropertyScopable
  # to prevent IDOR (other users cannot enqueue jobs against your property).
  class AnalysisRetriesController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    def create
      PdfAnalysisJob.perform_later(property_id: @property.id, user_id: current_user.id)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("global_toasts", partial: "notifications/toast",
              locals: { message: "분석을 다시 시작했습니다", type: :info }),
            turbo_stream.replace("analysis_indicator", partial: "notifications/analysis_indicator",
              locals: { active: true })
          ]
        end
        format.html do
          redirect_to edit_property_inspections_tab_path(@property, tab_key: "rights_analysis"),
                      notice: "분석을 다시 시작했습니다."
        end
      end
    end
  end
end
