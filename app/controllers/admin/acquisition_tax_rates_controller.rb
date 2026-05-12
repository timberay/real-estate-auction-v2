module Admin
  class AcquisitionTaxRatesController < BaseController
    before_action :load_rate, only: [ :edit, :update, :destroy ]

    def index
      @rates = AcquisitionTaxRate
        .includes(:property_type)
        .order(:property_type_id, :household_tier, :price_bucket_min_manwon, :area_over_85)
    end

    def new
      @rate = AcquisitionTaxRate.new
    end

    def create
      @rate = AcquisitionTaxRate.new(create_params)
      if @rate.save
        record_audit("created", @rate, { after: @rate.attributes })
        redirect_to admin_acquisition_tax_rates_url,
                    notice: "새 취득세율을 추가했습니다."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      before_snapshot = @rate.attributes
      if @rate.update(rate_params)
        record_audit("updated", @rate,
                     { before: before_snapshot, after: @rate.attributes })
        redirect_to admin_acquisition_tax_rates_url,
                    notice: "취득세율을 업데이트했습니다."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      destroyed_id = @rate.id
      before_snapshot = @rate.attributes
      @rate.destroy
      # Pass nil for rate so the audit row stores the id but no FK link
      # (the row is gone — we record the old id directly).
      AcquisitionTaxRateAuditLog.create!(
        acquisition_tax_rate_id: destroyed_id,
        user_id: current_user.id,
        action: "destroyed",
        changes_json: { before: before_snapshot }.to_json
      )
      redirect_to admin_acquisition_tax_rates_url,
                  notice: "취득세율 행을 삭제했습니다."
    end

    private

    def load_rate
      @rate = AcquisitionTaxRate.find(params[:id])
    end

    # F-D-3 — write an append-only audit row for a successful mutation.
    # `rate` may be nil only for the `destroyed` action when callers
    # prefer to detach the FK; we still always have the JSON payload.
    def record_audit(action, rate, payload)
      AcquisitionTaxRateAuditLog.create!(
        acquisition_tax_rate_id: rate&.id,
        user_id: current_user.id,
        action: action,
        changes_json: payload.to_json
      )
    end

    # On edit, property_type_id + household_tier are identity-like keys and
    # stay immutable so a typo cannot silently rewire which rate a calculator
    # pulls. On create, both must be set, hence the wider `create_params`
    # whitelist below.
    def rate_params
      params.expect(acquisition_tax_rate: [
        :price_bucket_min_manwon, :price_bucket_max_manwon,
        :area_over_85, :regulated_region, :total_rate
      ])
    end

    def create_params
      params.expect(acquisition_tax_rate: [
        :property_type_id, :household_tier,
        :price_bucket_min_manwon, :price_bucket_max_manwon,
        :area_over_85, :regulated_region, :total_rate
      ])
    end
  end
end
