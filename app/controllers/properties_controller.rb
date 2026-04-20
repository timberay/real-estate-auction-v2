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

    # Load persisted search results with pagination
    existing_case_numbers = current_user.properties.pluck(:case_number)
    search_scope = current_user.search_results
      .where.not(case_number: existing_case_numbers)
      .order(created_at: :desc)

    total_displayable = search_scope.count
    @total_pages = (total_displayable.to_f / 20).ceil
    @search_page = params[:search_page].to_i.clamp(1, [ @total_pages, 1 ].max)
    @search_results = search_scope.offset((@search_page - 1) * 20).limit(20)
    @api_total_count = current_user.last_search_api_total_count
    @over_api_limit = @api_total_count.to_i > 100
  end

  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)

    unless @property.analyzed?
      redirect_to new_analysis_path(property_id: @property.id)
      return
    end

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

  def destroy
    property = Property.find(params[:id])
    user_property = current_user.user_properties.find_by!(property: property)

    ActiveRecord::Base.transaction do
      InspectionResult.where(user: current_user, property: property).delete_all
      RightsAnalysisReport.where(user: current_user, property: property).delete_all
      LlmAnalysisLog.where(user: current_user, property: property).delete_all
      user_property.destroy!
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(property, :card)) }
      format.html { redirect_to properties_path, notice: "물건을 내 목록에서 삭제했습니다." }
    end
  end
end
