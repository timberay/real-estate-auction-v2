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

      unless @setting.valid?
        load_show_data
        render :show, status: :unprocessable_entity
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
        loan_ratio: @setting.loan_ratio.to_f
      )

      @setting.max_bid_amount = result[:max_bid_amount]

      if @setting.save
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

    def update_region
      @setting = current_user.budget_setting
      if @setting.update(region: params.dig(:budget_setting, :region))
        head :ok
      else
        head :unprocessable_entity
      end
    end

    private

    def load_show_data
      @property_types = PropertyType.enabled.ordered
      @loan_policies_by_type = LoanPolicy.active
        .where(property_type_id: @property_types.pluck(:id))
        .group_by(&:property_type_id)
      @loan_policies = @loan_policies_by_type[@setting.property_type_id] || []
      remap_stale_loan_policy
      @reserve_defaults = ReserveFundDefault.where(
        property_type_id: @property_types.pluck(:id)
      ).group_by(&:property_type_id)
    end

    # If the saved loan_policy_id refers to a policy from a different property type
    # (e.g., user changed property type but didn't reselect a policy), find the
    # equivalent policy by name in the current property type. In-memory only — the
    # DB stays as-is until the user submits the form.
    def remap_stale_loan_policy
      return if @setting.loan_policy_id.blank?
      return if @loan_policies.any? { |p| p.id == @setting.loan_policy_id }

      stale_policy = LoanPolicy.find_by(id: @setting.loan_policy_id)
      return unless stale_policy

      equivalent = @loan_policies.find { |p| p.policy_name == stale_policy.policy_name }
      return unless equivalent

      @setting.loan_policy_id = equivalent.id
      @setting.loan_ratio = equivalent.loan_ratio
    end

    def budget_params
      params.expect(budget_setting: [
        :available_cash, :property_type_id, :area_category,
        :repair_cost, :acquisition_tax, :scrivener_fee,
        :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio,
        :region
      ])
    end
  end
end
