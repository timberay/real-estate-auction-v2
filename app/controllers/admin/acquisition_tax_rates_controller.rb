module Admin
  class AcquisitionTaxRatesController < BaseController
    before_action :load_rate, only: [ :edit, :update ]

    def index
      @rates = AcquisitionTaxRate
        .includes(:property_type)
        .order(:property_type_id, :household_tier, :price_bucket_min_manwon, :area_over_85)
    end

    def edit
    end

    def update
      if @rate.update(rate_params)
        redirect_to admin_acquisition_tax_rates_url,
                    notice: "취득세율을 업데이트했습니다."
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def load_rate
      @rate = AcquisitionTaxRate.find(params[:id])
    end

    # property_type_id + household_tier are identity-like keys and stay
    # immutable here; if a row needs a different tier or asset class,
    # admins should add a new row (F-D-2 will surface create/destroy).
    def rate_params
      params.expect(acquisition_tax_rate: [
        :price_bucket_min_manwon, :price_bucket_max_manwon,
        :area_over_85, :regulated_region, :total_rate
      ])
    end
  end
end
