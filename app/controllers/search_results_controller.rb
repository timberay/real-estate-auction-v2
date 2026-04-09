class SearchResultsController < ApplicationController
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
  end

  def create
    result = CourtAuctionSearchService.call(user: current_user)

    if result.error
      redirect_to search_results_path, alert: error_message_for(result.error)
    else
      redirect_to search_results_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
    end
  end

  def import
    search_result = current_user.search_results.find(params[:id])
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      current_user.user_properties.find_or_create_by!(property: property)
      redirect_to properties_path, notice: "물건이 내 목록에 추가되었습니다."
      return
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      redirect_to properties_path, notice: "물건이 추가되었습니다."
    else
      error = result.errors[:court]
      redirect_to search_results_path, alert: error_message_for(error)
    end
  end

  private

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
