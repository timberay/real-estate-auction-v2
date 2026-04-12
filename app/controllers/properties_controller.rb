class PropertiesController < ApplicationController
  def index
    @user_properties = current_user.user_properties
      .includes(property: :inspection_results)
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

    if property.nil?
      redirect_to properties_path, alert: "해당 사건번호의 물건을 찾을 수 없습니다."
      return
    end

    if current_user.user_properties.exists?(property: property)
      redirect_to properties_path, notice: "이미 내 목록에 있는 물건입니다."
    else
      current_user.user_properties.create!(property: property)
      redirect_to property_path(property), notice: "내 목록에 추가했습니다."
    end
  end
end
