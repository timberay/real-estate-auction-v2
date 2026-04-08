class OnboardingsController < ApplicationController
  before_action :find_or_initialize_budget_setting, except: [ :complete ]

  def step1
    render :step1
  end

  def complete
    @setting = current_user.budget_setting
    @snapshot = current_user.budget_snapshots.order(version: :desc).first
    redirect_to start_onboarding_url unless @setting&.completed?
  end

  # POST /onboarding/step1 — saves cash, renders step2
  def create_step1
    @setting.available_cash = step1_params[:available_cash]

    if @setting.save
      load_step2_data
      render :step2
    else
      render :step1, status: :unprocessable_entity
    end
  end

  # POST /onboarding/step2 — saves reserves, renders step3
  def create_step2
    permitted = step2_params
    area_key = permitted.delete(:area_category)
    @setting.assign_attributes(permitted)
    range = BudgetSetting.area_range_for(area_key)
    @setting.area_range_min = range[:min] if range[:min]
    @setting.area_range_max = range[:max] if range[:max]

    if @setting.save
      load_step3_data
      render :step3
    else
      load_step2_data
      render :step2, status: :unprocessable_entity
    end
  end

  # POST /onboarding/step3 — calculates, saves, creates snapshot, redirects to complete
  def create_step3
    @setting.assign_attributes(step3_params)

    unless @setting.available_cash.present?
      redirect_to start_onboarding_url
      return
    end

    result = BudgetCalculationService.call(
      available_cash: @setting.available_cash,
      reserve_funds: {
        repair: @setting.repair_cost.to_i,
        acquisition_tax: @setting.acquisition_tax.to_i,
        scrivener: @setting.scrivener_fee.to_i,
        moving: @setting.moving_cost.to_i,
        maintenance: @setting.maintenance_fee.to_i
      },
      loan_ratio: @setting.loan_ratio.to_f,
      failed_auction_rounds: @setting.failed_auction_rounds
    )

    @setting.max_bid_amount = result[:max_bid_amount]
    @setting.searchable_appraisal_limit = result[:searchable_appraisal_limit]
    @setting.completed_at = Time.current

    if @setting.save
      BudgetSnapshotService.create(user: current_user, trigger: "onboarding")
      redirect_to complete_onboarding_url
    else
      load_step3_data
      render :step3, status: :unprocessable_entity
    end
  rescue BudgetCalculationService::InsufficientFundsError
    @setting.errors.add(:available_cash, "이(가) 예비비 합계보다 작습니다")
    load_step3_data
    render :step3, status: :unprocessable_entity
  end

  private

  def find_or_initialize_budget_setting
    @setting = current_user.budget_setting || current_user.build_budget_setting
  end

  def step1_params
    params.expect(budget_setting: [ :available_cash ])
  end

  def step2_params
    params.expect(budget_setting: [
      :property_type_id, :area_category,
      :repair_cost, :acquisition_tax, :scrivener_fee, :moving_cost, :maintenance_fee
    ])
  end

  def step3_params
    params.expect(budget_setting: [ :loan_policy_id, :loan_ratio, :failed_auction_rounds ])
  end

  def load_step2_data
    @property_types = PropertyType.enabled.ordered
    @reserve_defaults = ReserveFundDefault.where(
      property_type_id: @property_types.pluck(:id)
    ).group_by(&:property_type_id)
    apply_step2_defaults
  end

  def apply_step2_defaults
    return if @setting.area_range_min.present?

    @setting.area_range_min = 60  # 중형 lower bound
    @setting.area_range_max = 85  # 중형 upper bound
    @setting.property_type_id ||= @property_types.first&.id
  end

  def load_step3_data
    @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
  end
end
