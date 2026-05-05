class UpdateLoanPoliciesForRegionAwareLtv < ActiveRecord::Migration[8.1]
  # 2026-05 regulation update — non-regulated max for 무주택 일반 + add regulated_loan_ratio
  # column for 서울 / regulated areas (capped at apartment 40% / villa 40% / officetel 40%
  # for 1금융, all 70-80% for 2금융 P2P 우회로).
  RATES = {
    "apartment" => {
      "경락대출 (1금융)" => { non_regulated: 0.70, regulated: 0.40 },
      "경락대출 (2금융)" => { non_regulated: 0.80, regulated: 0.80 }
    },
    "villa" => {
      "경락대출 (1금융)" => { non_regulated: 0.60, regulated: 0.40 },
      "경락대출 (2금융)" => { non_regulated: 0.70, regulated: 0.70 }
    },
    "officetel" => {
      "경락대출 (1금융)" => { non_regulated: 0.70, regulated: 0.40 },
      "경락대출 (2금융)" => { non_regulated: 0.80, regulated: 0.80 }
    }
  }.freeze

  def up
    add_column :loan_policies, :regulated_loan_ratio, :decimal, precision: 3, scale: 2

    LoanPolicy.reset_column_information
    LoanPolicy.includes(:property_type).find_each do |policy|
      rates = RATES.dig(policy.property_type&.code, policy.policy_name)
      next unless rates

      policy.update_columns(
        loan_ratio: rates[:non_regulated],
        regulated_loan_ratio: rates[:regulated]
      )
    end

    # Any policies without a rates mapping still need a regulated value to satisfy NOT NULL;
    # default to the non-regulated ratio so the upgrade never silently leaves nils.
    LoanPolicy.where(regulated_loan_ratio: nil).find_each do |policy|
      policy.update_columns(regulated_loan_ratio: policy.loan_ratio)
    end

    change_column_null :loan_policies, :regulated_loan_ratio, false
  end

  def down
    remove_column :loan_policies, :regulated_loan_ratio
  end
end
