class LoanPolicyAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentLoanPolicyAdapter.new
    else
      MockLoanPolicyAdapter.new
    end
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
