class LoanPolicyAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentLoanPolicyAdapter.new
    else
      MockLoanPolicyAdapter.new
    end
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
