module Properties
  class DocumentsController < ApplicationController
    before_action :set_property

    def create
      if params[:documents].blank?
        redirect_to property_path(@property), alert: "파일을 선택해주세요."
        return
      end

      params[:documents].each do |file|
        unless file.content_type == "application/pdf"
          redirect_to property_path(@property), alert: "PDF 파일만 업로드할 수 있습니다."
          return
        end
      end

      @property.documents.attach(params[:documents])
      redirect_to property_path(@property), notice: "문서가 업로드되었습니다."
    end

    def destroy
      attachment = @property.documents.find(params[:id])
      attachment.purge
      redirect_to property_path(@property), notice: "문서가 삭제되었습니다."
    end

    private

    def set_property
      @property = Property.find(params[:property_id])
    end
  end
end
