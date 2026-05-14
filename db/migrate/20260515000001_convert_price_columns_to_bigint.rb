class ConvertPriceColumnsToBigint < ActiveRecord::Migration[8.1]
  def change
    change_column :search_results, :appraisal_price, :bigint
    change_column :search_results, :min_bid_price, :bigint

    change_column :rights_analysis_reports, :total_risk_amount, :bigint, default: 0, null: false
    change_column :rights_analysis_reports, :assumed_amount, :bigint, default: 0, null: false
  end
end
