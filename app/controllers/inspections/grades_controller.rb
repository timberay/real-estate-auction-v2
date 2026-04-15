module Inspections
  class GradesController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      rating_service = InspectionRatingService.new(property: @property, user: current_user)
      @rating = rating_service.call
      @fully_evaluated = rating_service.fully_evaluated?
      @tabs_evaluated, @tabs_total = rating_service.tabs_evaluated_count
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)
      @budget_setting = current_user.budget_setting

      all_results = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
      property_type = @property.property_type

      @results_by_tab = all_results
        .select { |r| r.inspection_item.visible_for?(property_type:, answered_results: answered_context, all_items_by_code: all_items_by_code) }
        .group_by { |r| r.inspection_item.tab }

      @risk_results = @property.inspection_results
        .where(has_risk: true, user: current_user)
        .includes(:inspection_item)
        .order("inspection_items.tab, inspection_items.tab_position")

      respond_to do |format|
        format.html
        format.pdf { send_report_pdf }
      end
    end

    private

    def send_report_pdf
      html = render_to_string(template: "inspections/grades/show", formats: [ :pdf ], layout: "report_pdf")
      pdf_binary = PdfExportService.call(html: html)
      filename = "경매분석리포트_#{@property.case_number}_#{Date.current}.pdf"
      send_data pdf_binary, filename: filename, type: "application/pdf", disposition: "attachment"
    end
  end
end
