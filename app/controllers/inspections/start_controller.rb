module Inspections
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])

      if params[:documents].present?
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
