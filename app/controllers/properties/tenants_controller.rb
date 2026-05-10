module Properties
  class TenantsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property
    before_action :set_report
    before_action :set_tenant_index

    def edit
    end

    def update
    end

    private

    def set_report
      @report = RightsAnalysisReport.find_by!(user: current_user, property: @property)
    end

    def set_tenant_index
      @tenant_index = Integer(params[:id])
      render plain: "Not Found", status: :not_found unless @tenant_index < @report.effective_tenants.size
    rescue ArgumentError, TypeError
      render plain: "Not Found", status: :not_found
    end

    def tenant_params
      params.require(:tenant).permit(:deposit, :move_in_date, :confirmed_date)
    end
  end
end
