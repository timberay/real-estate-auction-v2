class PropertiesController < ApplicationController
  include CourtAuctionErrorMessages
  def index
    @user_properties = current_user.user_properties
      .includes(property: :inspection_results)
      .ordered_for_list
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
      @user_properties = @user_properties.joins(:property).where("properties.min_bid_price <= ?", @max_bid_amount * 10000)
    end
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
    case_number = params[:case_number].to_s.strip
    court_code  = params[:court_code].to_s.strip

    unless valid_inputs?(case_number, court_code)
      redirect_to properties_path, alert: "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
      return
    end

    result = CaseSearchService.call(court_code: court_code, case_number: case_number)

    if result.error
      redirect_to properties_path, alert: error_message_for(result.error)
      return
    end

    property = result.properties.first
    current_user.user_properties.find_or_create_by!(property: property)
    redirect_to properties_path, notice: "내 목록에 추가했습니다."
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

  def toggle_favorite
    user_property = current_user.user_properties.find_by!(property_id: params[:id])
    user_property.update!(favorite: !user_property.favorite)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(user_property, :favorite_toggle),
          FavoriteToggleComponent.new(user_property: user_property)
        )
      end
      format.html { redirect_to properties_path }
    end
  end

  private

  def valid_inputs?(case_number, court_code)
    return false if case_number.blank? || court_code.blank?
    return false unless CourtAuction::CaseSearchClient::COURT_CODES.value?(court_code)

    CourtAuction::CaseNumberParser.parse(case_number)
    true
  rescue DataProvider::ParseError
    false
  end
end
