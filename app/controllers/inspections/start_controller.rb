module Inspections
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])

      unless @property.documents.attached?
        redirect_to property_path(@property), alert: "분석할 문서를 먼저 업로드해주세요."
        return
      end

      PdfAnalysisJob.perform_later(
        property_id: @property.id,
        user_id: current_user.id
      )

      redirect_to property_path(@property), notice: "분석이 시작되었습니다."
    end
  end
end
