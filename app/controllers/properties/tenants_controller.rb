module Properties
  class TenantsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property
    before_action :set_report
    before_action :set_tenant_index

    def edit
      @tenant = @report.effective_tenants[@tenant_index]
    end

    def update
      @report.update_tenant!(@tenant_index, tenant_params.to_h.symbolize_keys)

      respond_to do |format|
        format.turbo_stream do
          @tenant = @report.reload.effective_tenants[@tenant_index]
          render turbo_stream: turbo_stream.replace(
            "tenant-row-#{@tenant_index}",
            partial: "properties/tenants/row",
            locals: { tenant: @tenant, index: @tenant_index, report: @report, property: @property }
          )
        end
        format.html { redirect_to property_path(@property) }
      end
    end

    private

    def set_report
      @report = RightsAnalysisReport.find_by!(user: current_user, property: @property)
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
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
