module Properties
  class DocumentsController < ApplicationController
    include PropertyScopable
    include PdfUploadValidatable
    before_action :set_user_property

    def create
      if params[:documents].blank?
        redirect_to property_path(@property), alert: "파일을 선택해주세요."
        return
      end

      if (err = validate_pdf_uploads(params[:documents]))
        redirect_to property_path(@property), alert: err
        return
      end

      @property.documents.attach(params[:documents])
      redirect_to property_path(@property), notice: "문서가 업로드되었습니다."
    end

    def destroy
      attachment = @property.documents.find(params[:id])
      attachment.purge
      redirect_to property_path(@property), notice: "문서가 삭제되었습니다."
    end
  end
end
