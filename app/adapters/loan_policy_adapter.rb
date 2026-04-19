class LoanPolicyAdapter
  def self.for(_config = {})
    StaticLoanPolicyAdapter.new
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
