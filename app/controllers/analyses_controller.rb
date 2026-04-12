class AnalysesController < ApplicationController
  def new
  end

  def prompt
    items = InspectionItem.ordered
    prompts = Inspection::PdfPromptBuilder.call(items: items)

    markdown = <<~MD
      # 부동산 경매 AI 분석 프롬프트

      아래 내용을 AI에게 전달하고, 법원경매 PDF 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본)와 함께 분석을 요청하세요.

      **중요:** 결과는 반드시 마지막 섹션의 JSON 형식으로 받아주세요.

      ---

      ## 시스템 프롬프트

      #{prompts[:system]}

      ---

      ## 사용자 프롬프트

      #{prompts[:user]}

      ---

      ## 기대 응답 형식 (JSON)

      AI의 응답이 아래 구조를 따르는지 확인하세요:

      ```json
      {
        "metadata": {
          "court_name": "관할 법원명",
          "case_number": "사건번호",
          "address": "소재지",
          "property_type": "물건종류",
          "appraisal_price": 0,
          "min_bid_price": 0
        },
        "results": {
          "<item_code>": {
            "has_risk": true,
            "confidence": "high",
            "reasoning": "판정 근거"
          }
        },
        "rights_analysis": {
          "verdict": "safe",
          "verdict_summary": "한줄 요약",
          "base_right_type": "근저당권",
          "base_right_holder": "권리자명",
          "base_right_date": "YYYY-MM-DD",
          "opportunity_type": null,
          "opportunity_reason": null,
          "tenants": [],
          "rights_timeline": [],
          "reasoning": "분석 근거",
          "checklist_references": []
        }
      }
      ```
    MD

    send_data markdown,
      filename: "auction-analysis-prompt.md",
      type: "text/markdown",
      disposition: "attachment"
  end

  def manual
    unless params[:json_file].present?
      redirect_to new_analysis_path, alert: "JSON 파일을 업로드해주세요."
      return
    end

    json_string = params[:json_file].read
    parsed = begin
      JSON.parse(json_string)
    rescue JSON::ParserError
      redirect_to new_analysis_path, alert: "유효한 JSON 파일이 아닙니다."
      return
    end

    unless parsed.key?("metadata")
      redirect_to new_analysis_path, alert: "JSON에 metadata 키가 필요합니다."
      return
    end

    unless parsed.key?("results")
      redirect_to new_analysis_path, alert: "JSON에 results 키가 필요합니다."
      return
    end

    unless parsed.dig("metadata", "case_number").present?
      redirect_to new_analysis_path, alert: "metadata.case_number가 필요합니다."
      return
    end

    result = PdfAnalysisService.call(response_json: parsed, user: current_user)

    if result.success?
      redirect_to edit_property_inspections_tab_path(result.property, tab_key: "rights_analysis"),
        notice: "분석 결과가 저장되었습니다."
    else
      redirect_to new_analysis_path, alert: "분석 결과 저장 중 오류가 발생했습니다: #{result.error}"
    end
  rescue => e
    redirect_to new_analysis_path, alert: "분석 결과 저장 중 오류가 발생했습니다: #{e.message}"
  end

  def create
    uploaded_files = Array(params[:documents]).reject { |f| f.is_a?(String) }

    if uploaded_files.empty?
      redirect_to new_analysis_path, alert: "PDF 파일을 업로드해주세요."
      return
    end

    blob_ids = uploaded_files.map do |file|
      unless file.content_type == "application/pdf"
        redirect_to new_analysis_path, alert: "PDF 파일만 업로드할 수 있습니다."
        return
      end
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type
      ).id
    end

    PdfAnalysisJob.perform_later(
      property_id: nil,
      user_id: current_user.id,
      document_blob_ids: blob_ids
    )

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
end
