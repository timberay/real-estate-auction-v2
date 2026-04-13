class LoanPolicyAdapter
  def self.for(_config = {})
    MockLoanPolicyAdapter.new
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
