module Settings
  class BudgetsController < ApplicationController
    def show
      @setting = current_user.budget_setting
      redirect_to start_onboarding_url unless @setting&.completed?
      load_show_data
    end

    def update
      @setting = current_user.budget_setting

      permitted = budget_params
      area_key = permitted.delete(:area_category)
      @setting.assign_attributes(permitted)
      range = BudgetSetting.area_range_for(area_key)
      @setting.area_range_min = range[:min] if range[:min]
      @setting.area_range_max = range[:max] if range[:max]

      result = BudgetCalculationService.call(
        available_cash: @setting.available_cash,
        reserve_funds: {
          repair: @setting.repair_cost.to_i,
          acquisition_tax: @setting.acquisition_tax.to_i,
          scrivener: @setting.scrivener_fee.to_i,
          moving: @setting.moving_cost.to_i,
          maintenance: @setting.maintenance_fee.to_i
        },
        loan_ratio: @setting.loan_ratio.to_f
      )

      @setting.max_bid_amount = result[:max_bid_amount]

      if @setting.save
        BudgetSnapshotService.create(user: current_user, trigger: "manual_edit")
        redirect_to settings_budget_url, notice: "예산 설정이 업데이트되었습니다."
      else
        load_show_data
        render :show, status: :unprocessable_entity
      end
    rescue BudgetCalculationService::InsufficientFundsError
      @setting.errors.add(:available_cash, "이(가) 예비비 합계보다 작습니다")
      load_show_data
      render :show, status: :unprocessable_entity
    end

    private

    def load_show_data
      @property_types = PropertyType.enabled.ordered
      @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
      @reserve_defaults = ReserveFundDefault.where(
        property_type_id: @property_types.pluck(:id)
      ).group_by(&:property_type_id)
    end

    def budget_params
      params.expect(budget_setting: [
        :available_cash, :property_type_id, :area_category,
        :repair_cost, :acquisition_tax, :scrivener_fee,
        :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio
      ])
    end
  end
end
