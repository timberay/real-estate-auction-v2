class LoanPolicySyncService
  def self.call
    new.call
  end

  def call
    adapter = LoanPolicyAdapter.for
    synced = 0
    skipped = 0
    types_processed = []

    PropertyType.enabled.find_each do |pt|
      types_processed << pt.code
      policies = adapter.fetch_policies(property_type_code: pt.code)

      policies.each do |policy_data|
        existing = LoanPolicy.find_by(
          property_type: pt,
          policy_name: policy_data[:policy_name]
        )

        if existing
          if policy_changed?(existing, policy_data)
            existing.update!(
              loan_ratio: policy_data[:loan_ratio],
              regulated_loan_ratio: policy_data[:regulated_loan_ratio],
              description: policy_data[:description],
              source_url: policy_data[:source_url],
              effective_date: policy_data[:effective_date]
            )
            synced += 1
          else
            skipped += 1
          end
        else
          LoanPolicy.create!(
            property_type: pt,
            policy_name: policy_data[:policy_name],
            loan_ratio: policy_data[:loan_ratio],
            regulated_loan_ratio: policy_data[:regulated_loan_ratio],
            description: policy_data[:description],
            source_url: policy_data[:source_url],
            effective_date: policy_data[:effective_date],
            enabled: true
          )
          synced += 1
        end
      end
    end

    { synced_count: synced, skipped_count: skipped, property_types_processed: types_processed }
  end

  private

  def policy_changed?(existing, new_data)
    existing.loan_ratio.to_f != new_data[:loan_ratio].to_f ||
      existing.regulated_loan_ratio.to_f != new_data[:regulated_loan_ratio].to_f ||
      existing.description != new_data[:description] ||
      existing.source_url != new_data[:source_url]
  end
end
