module Inspections
  class StartController < ApplicationController
    include PropertyScopable
    include PdfUploadValidatable
    before_action :set_user_property

    def create
      if params[:documents].present?
        if (err = validate_pdf_uploads(params[:documents]))
          redirect_to property_path(@property), alert: err
          return
        end
        @property.documents.attach(params[:documents])
      end

      unless @property.documents.attached?
        redirect_to property_path(@property), alert: "분석할 문서를 먼저 업로드해주세요."
        return
      end

      PdfAnalysisJob.perform_later(
        property_id: @property.id,
        user_id: current_user.id
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_notifications_#{current_user.id}",
        target: "analysis_indicator",
        partial: "notifications/analysis_indicator",
        locals: { active: true }
      )

      redirect_to property_path(@property), notice: "분석이 시작되었습니다."
    end
  end
end
