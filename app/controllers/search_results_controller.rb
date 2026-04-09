class SearchResultsController < ApplicationController
  include ActionView::RecordIdentifier
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
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
        if result.error
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_error",
            locals: { message: error_message_for(result.error) })
        else
          search_results = current_user.search_results.order(created_at: :desc)
          @user_property_case_numbers = current_user.properties.pluck(:case_number)
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: search_results, user_property_case_numbers: @user_property_case_numbers })
        end
      end
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
      redirect_to properties_path, notice: "#{search_result.case_number} 물건이 추가되었습니다."
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
      current_user.user_properties.find_or_create_by!(property: property)
      return { success: true }
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      result.property.update!(property_count: search_result.property_count) if search_result.property_count > 1
      current_user.user_properties.create!(property: result.property)
      { success: true }
    else
      Rails.logger.warn "[InlineImport] Detail fetch failed for #{case_number}, creating from search data"
      property = create_property_from_search_result(search_result)
      current_user.user_properties.create!(property: property)
      { success: true }
    end
  end

  def create_property_from_search_result(search_result)
    Property.create!(
      case_number: search_result.case_number,
      address: search_result.address,
      appraisal_price: search_result.appraisal_price,
      min_bid_price: search_result.min_bid_price,
      property_type: search_result.property_type,
      status: search_result.status,
      failed_bid_count: search_result.failed_bid_count,
      property_count: search_result.property_count
    )
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
