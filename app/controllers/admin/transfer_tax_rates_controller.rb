module Admin
  class TransferTaxRatesController < BaseController
    before_action :load_rate, only: [ :edit, :update, :destroy ]

    def index
      @rates = TransferTaxRate
        .includes(:property_type)
        .order(:property_type_id, :household_tier, :holding_period, :regulated_region)
    end

    def new
      @rate = TransferTaxRate.new
    end

    def create
      @rate = TransferTaxRate.new(create_params)
      if @rate.save
        record_audit("created", @rate, { after: @rate.attributes })
        redirect_to admin_transfer_tax_rates_url,
                    notice: "새 양도세율을 추가했습니다."
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
        redirect_to admin_transfer_tax_rates_url,
                    notice: "양도세율을 업데이트했습니다."
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
      TransferTaxRateAuditLog.create!(
        transfer_tax_rate_id: destroyed_id,
        user_id: current_user.id,
        action: "destroyed",
        changes_json: { before: before_snapshot }.to_json
      )
      redirect_to admin_transfer_tax_rates_url,
                  notice: "양도세율 행을 삭제했습니다."
    end

    private

    def load_rate
      @rate = TransferTaxRate.find(params[:id])
    end

    # T1.2-F-C — write an append-only audit row for a successful mutation.
    # `rate` may be nil only for the `destroyed` action when callers
    # prefer to detach the FK; we still always have the JSON payload.
    def record_audit(action, rate, payload)
      TransferTaxRateAuditLog.create!(
        transfer_tax_rate_id: rate&.id,
        user_id: current_user.id,
        action: action,
        changes_json: payload.to_json
      )
    end

    # On edit, property_type_id + household_tier + holding_period are
    # identity-like keys and stay immutable so a typo cannot silently rewire
    # which rate a calculator pulls. On create, all five must be set.
    def rate_params
      params.expect(transfer_tax_rate: [
        :regulated_region, :total_rate
      ])
    end

    def create_params
      params.expect(transfer_tax_rate: [
        :property_type_id, :household_tier, :holding_period,
        :regulated_region, :total_rate
      ])
    end
  end
end
