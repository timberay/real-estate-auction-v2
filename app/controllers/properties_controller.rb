class PropertiesController < ApplicationController
  def index
    @user_properties = current_user.user_properties
      .includes(:property)
      .order(created_at: :desc)
    @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @user_properties = @user_properties.joins(:property).where(
        "properties.case_number LIKE :q OR properties.address LIKE :q OR properties.court_name LIKE :q",
        q: search_term
      )
    end
    @max_bid_amount = current_user.budget_setting&.max_bid_amount
    if params[:within_budget] == "1" && @max_bid_amount.present?
      @user_properties = @user_properties.joins(:property).where("properties.appraisal_price <= ?", @max_bid_amount)
    end
  end

  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)
    @check_results = @property.property_check_results
      .where(user: current_user)
      .includes(:checklist_item)
      .order("checklist_items.position")
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
      property = PropertyDataSyncService.call(case_number: case_number)
      if property
        current_user.user_properties.create!(property: property)
        redirect_to properties_path, notice: "물건이 추가되었습니다."
      else
        redirect_to properties_path, alert: "해당 사건번호의 물건을 찾을 수 없습니다."
      end
    end
  end
end
