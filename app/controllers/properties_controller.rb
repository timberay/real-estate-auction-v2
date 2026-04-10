class PropertiesController < ApplicationController
  def index
    @user_properties = current_user.user_properties
      .includes(:property)
      .order(created_at: :desc)
    @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @user_properties = @user_properties.joins(:property).where(
        "properties.case_number LIKE :q OR properties.address LIKE :q OR properties.building_name LIKE :q",
        q: search_term
      )
    end
    @max_bid_amount = current_user.budget_setting&.max_bid_amount
    @setting = current_user.budget_setting
    if params[:within_budget] == "1" && @max_bid_amount.present?
      @user_properties = @user_properties.joins(:property).where("properties.appraisal_price <= ?", @max_bid_amount * 10000)
    end

    # Load persisted search results for inline display
    existing_case_numbers = current_user.properties.pluck(:case_number)
    search_results = current_user.search_results
      .where.not(case_number: existing_case_numbers)
      .order(created_at: :desc)
    total_count = search_results.count
    @over_limit = total_count > 20
    @search_results = search_results.limit(20)
  end

  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)

    if @user_property&.safety_rating.present?
      redirect_to property_inspections_grade_path(@property)
    elsif @user_property&.analyzed_at.present?
      redirect_to edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")
    end
  end

  def create
    case_number = params[:case_number]&.strip

    if case_number.blank?
      redirect_to properties_path, alert: "사건번호를 입력해주세요."
      return
    end

    property = Property.find_by(case_number: case_number)

    if property
      if current_user.user_properties.exists?(property: property)
        redirect_to properties_path, notice: "이미 내 목록에 있는 물건입니다."
      else
        current_user.user_properties.create!(property: property)
        redirect_to properties_path, notice: "이미 등록된 물건입니다. 내 목록에 추가했습니다."
      end
    else
      # Step 1: Discover which court holds this case
      discovery = CaseSearchService.find_by_case_number(case_number: case_number)

      unless discovery.success?
        redirect_to properties_path, alert: discovery_error_message(discovery.error)
        return
      end

      # Step 2: Fetch full details via existing sync service
      result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
      if result.property
        current_user.user_properties.create!(property: result.property)
        redirect_to properties_path, notice: "물건이 추가되었습니다."
      else
        error = result.errors[:court]
        redirect_to properties_path, alert: error_message_for(error)
      end
    end
  rescue DataProvider::ParseError => e
    if e.message.include?("Invalid case number format")
      redirect_to properties_path, alert: "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
    else
      redirect_to properties_path, alert: "데이터 처리 중 오류가 발생했습니다."
    end
  end

  private

  def discovery_error_message(error_string)
    if error_string.include?("unavailable")
      "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
    else
      "해당 사건번호의 물건을 찾을 수 없습니다."
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
    when DataProvider::ParseError
      if error.message.include?("Invalid case number format")
        "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
      else
        "데이터 처리 중 오류가 발생했습니다."
      end
    when DataProvider::DataNotFoundError, nil
      "해당 사건번호의 물건을 찾을 수 없습니다."
    else
      "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
    end
  end
end
