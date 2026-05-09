class AnalysesController < ApplicationController
  include PdfUploadValidatable

  def new
    if params[:property_id].present?
      @property = Property.find_by(id: params[:property_id])
      unless @property
        redirect_to new_analysis_path, alert: "해당 물건을 찾을 수 없습니다."
        nil
      end
    end
  end

  def prompt
    items = InspectionItem.ordered
    prompts = Inspection::PdfPromptBuilder.call(items: items)

    render json: { prompt: prompts[:system] + "\n\n" + prompts[:user] }
  end

  MAX_MANUAL_JSON_SIZE = 1.megabyte

  def manual
    if params[:json_file].present? && params[:json_file].size > MAX_MANUAL_JSON_SIZE
      redirect_to new_analysis_path(tab: "manual"), alert: "JSON 파일은 1MB를 초과할 수 없습니다."
      return
    end

    json_string = if params[:json_file].present?
      extract_json(params[:json_file].read.force_encoding("UTF-8"))
    elsif params[:json_text].present?
      extract_json(params[:json_text])
    end

    unless json_string.present?
      redirect_to new_analysis_path(tab: "manual"), alert: "JSON 파일을 업로드하거나 텍스트를 붙여넣어주세요."
      return
    end
    parsed = begin
      JSON.parse(json_string)
    rescue JSON::ParserError
      redirect_to new_analysis_path(tab: "manual"), alert: "유효한 JSON 파일이 아닙니다. JSON만 포함된 파일인지 확인해주세요."
      return
    end

    unless parsed.key?("metadata")
      redirect_to new_analysis_path(tab: "manual"), alert: "JSON에 metadata 키가 필요합니다."
      return
    end

    unless parsed.key?("results")
      redirect_to new_analysis_path(tab: "manual"), alert: "JSON에 results 키가 필요합니다."
      return
    end

    unless parsed.dig("metadata", "case_number").present?
      redirect_to new_analysis_path(tab: "manual"), alert: "metadata.case_number가 필요합니다."
      return
    end

    result = PdfAnalysisService.call(response_json: parsed, user: current_user)

    if result.success?
      redirect_to edit_property_inspections_tab_path(result.property, tab_key: "rights_analysis"),
        notice: "분석 결과가 저장되었습니다."
    else
      redirect_to new_analysis_path(tab: "manual"), alert: "분석 결과 저장 중 오류가 발생했습니다: #{result.error}"
    end
  rescue => e
    Rails.logger.error "[ManualUpload] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to new_analysis_path(tab: "manual"), alert: "분석 결과 저장 중 오류가 발생했습니다: #{e.message}"
  end

  def create
    property_id = params[:property_id].presence

    unless property_id
      redirect_to new_analysis_path, alert: "사건번호를 먼저 입력해 주세요."
      return
    end

    unless current_user.user_properties.exists?(property_id: property_id)
      redirect_to new_analysis_path, alert: "해당 물건을 찾을 수 없습니다."
      return
    end

    uploaded_files = Array(params[:documents]).reject { |f| f.is_a?(String) }

    if uploaded_files.empty?
      redirect_to new_analysis_path, alert: "PDF 파일을 업로드해주세요."
      return
    end

    if (err = validate_pdf_uploads(uploaded_files))
      redirect_to new_analysis_path, alert: err
      return
    end

    blob_ids = uploaded_files.map do |file|
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type
      ).id
    end

    PdfAnalysisJob.perform_later(
      property_id: property_id,
      user_id: current_user.id,
      document_blob_ids: blob_ids
    )

    # CaseNumberMissingError / CaseNumberMismatchError are raised inside PdfAnalysisJob
    # and broadcast to the user via Turbo Stream toast (see pdf_analysis_job.rb).
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("analysis_form", partial: "analyses/form"),
          turbo_stream.append("global_toasts", partial: "notifications/toast",
            locals: { message: "분석이 시작되었습니다", type: :info }),
          turbo_stream.replace("analysis_indicator", partial: "notifications/analysis_indicator",
            locals: { active: true })
        ]
      end
      format.html do
        redirect_to new_analysis_path, notice: "분석이 시작되었습니다."
      end
    end
  end

  private

  def extract_json(raw)
    # Strip UTF-8 BOM
    raw = raw.sub(/\A\xEF\xBB\xBF/, "")

    # Strip markdown code blocks (```json ... ``` or ``` ... ```)
    if raw.match?(/\A\s*```/)
      raw = raw.gsub(/\A\s*```(?:json)?\s*\n?/, "").gsub(/\n?\s*```\s*\z/, "")
    end

    # Extract first JSON object if surrounded by text
    if (match = raw.match(/(\{[\s\S]*\})\s*\z/))
      match[1]
    else
      raw
    end
  end
end
