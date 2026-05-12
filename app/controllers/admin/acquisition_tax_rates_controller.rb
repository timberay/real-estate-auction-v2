module Admin
  class AcquisitionTaxRatesController < BaseController
    def index
      @rates = AcquisitionTaxRate
        .includes(:property_type)
        .order(:property_type_id, :household_tier, :price_bucket_min_manwon, :area_over_85)
    end
  end
end
