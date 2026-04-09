class SearchResultsController < ApplicationController
  include ActionView::RecordIdentifier
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
  end

  def preview
    bs = current_user.budget_setting
    criteria = {
      region: bs&.effective_region || BudgetSetting::DEFAULT_REGION,
      year: Time.current.year.to_s,
      min_price: 50_000_000,
      max_price: bs&.max_price_option || BudgetSetting::DEFAULT_MAX_PRICE
    }

    render turbo_stream: turbo_stream.update("criteria-debug-popup",
      partial: "search_results/criteria_preview_popup",
      locals: { criteria: criteria })
  end

  def create
    result = CourtAuctionSearchService.call(user: current_user)

    respond_to do |format|
      format.html do
        if result.error
          redirect_to search_results_path, alert: error_message_for(result.error)
        else
          redirect_to search_results_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
        end
      end
      format.turbo_stream do
        streams = []
        if result.error
          streams << turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_error",
            locals: { message: error_message_for(result.error) })
        else
          @search_results = current_user.search_results.order(created_at: :desc)
          @user_property_case_numbers = current_user.properties.pluck(:case_number)
          streams << turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: @search_results, user_property_case_numbers: @user_property_case_numbers })
        end
        streams << turbo_stream.update("criteria-debug-popup",
          partial: "search_results/criteria_debug_popup",
          locals: { criteria: result.criteria, count: result.count, error: result.error })
        render turbo_stream: streams
      end
    end
  end

  def import
    search_result = current_user.search_results.find(params[:id])
    import_result = perform_import(search_result.case_number)

    if import_result[:success]
      redirect_to properties_path, notice: "물건이 내 목록에 추가되었습니다."
    else
      redirect_to search_results_path, alert: error_message_for(import_result[:error])
    end
  end

  def inline_import
    search_result = current_user.search_results.find(params[:id])
    import_result = perform_import(search_result.case_number)

    if import_result[:success]
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item",
        locals: { search_result: search_result, already_added: true })
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item_error",
        locals: { search_result: search_result, message: error_message_for(import_result[:error]) })
    end
  end

  private

  def perform_import(case_number)
    property = Property.find_by(case_number: case_number)
    if property
      current_user.user_properties.find_or_create_by!(property: property)
      return { success: true }
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      { success: true }
    else
      { success: false, error: result.errors[:court] }
    end
  end

  def error_message_for(error)
    case error
    when DataProvider::TimeoutError
      "데이터 수집 시간이 초과되었습니다. 다시 시도해주세요."
    when DataProvider::ServiceUnavailableError, DataProvider::ConnectionError
      "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
    when DataProvider::ConfigurationError
      "브라우저 실행에 실패했습니다. 시스템 설정을 확인해주세요."
    when DataProvider::DataNotFoundError, nil
      "해당 물건을 찾을 수 없습니다."
    else
      "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
    end
  end
end
