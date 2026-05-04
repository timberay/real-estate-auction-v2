class SearchResultsController < ApplicationController
  include ActionView::RecordIdentifier
  include CourtAuctionErrorMessages
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
  end

  def create
    bs = current_user.budget_setting
    result = CourtAuctionSearchService.call(
      user: current_user,
      address: bs&.effective_region || BudgetSetting::DEFAULT_REGION,
      max_bid_price: bs&.max_bid_amount.to_i * 10_000
    )

    if result.error
      redirect_to properties_path, alert: error_message_for(result.error)
    else
      redirect_to properties_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
    end
  end

  def import
    search_result = current_user.search_results.find(params[:id])
    import_result = perform_import(search_result)

    if import_result[:success]
      redirect_to properties_path, notice: "물건이 내 목록에 추가되었습니다."
    else
      redirect_to search_results_path, alert: error_message_for(import_result[:error])
    end
  end

  def inline_import
    search_result = current_user.search_results.find(params[:id])
    import_result = perform_import(search_result)

    if import_result[:success]
      property = import_result[:property]
      user_property = import_result[:user_property]
      existing_case_numbers = current_user.properties.pluck(:case_number)
      remaining_count = current_user.search_results
        .where.not(case_number: existing_case_numbers)
        .count

      streams = [
        turbo_stream.replace(
          dom_id(search_result, :inline),
          partial: "search_results/inline_result_fade_out",
          locals: { search_result: search_result }
        ),
        turbo_stream.append(
          "property-cards-grid",
          partial: "search_results/inline_imported_card",
          locals: { property: property, user_property: user_property, max_bid_amount: current_user.budget_setting&.max_bid_amount }
        ),
        turbo_stream.remove("user-properties-empty-state")
      ]

      if remaining_count == 0
        streams << turbo_stream.update("criteria-search-results", "")
      else
        streams << turbo_stream.update("criteria-search-count", html: "#{remaining_count}건")
      end

      render turbo_stream: streams
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item_error",
        locals: { search_result: search_result, message: error_message_for(import_result[:error]) })
    end
  end

  def clear
    current_user.search_results.destroy_all

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("criteria-search-results", "")
      end
      format.html { redirect_to properties_path }
    end
  end

  private

  def perform_import(search_result)
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      user_property = current_user.user_properties.find_or_create_by!(property: property)
      return { success: true, property: property, user_property: user_property }
    end

    property = create_property_from_search_result(search_result)
    user_property = current_user.user_properties.create!(property: property)
    { success: true, property: property, user_property: user_property }
  end

  def create_property_from_search_result(search_result)
    Property.create!(
      case_number: search_result.case_number,
      court_code: search_result.court_code,
      court_name: search_result.court_name,
      address: search_result.address,
      appraisal_price: search_result.appraisal_price,
      min_bid_price: search_result.min_bid_price,
      property_type: search_result.property_type,
      status: search_result.status,
      failed_bid_count: search_result.failed_bid_count,
      property_count: search_result.property_count
    )
  end
end
