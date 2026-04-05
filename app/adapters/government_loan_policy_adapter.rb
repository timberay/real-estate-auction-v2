class GovernmentLoanPolicyAdapter < LoanPolicyAdapter
  # Real implementation will call:
  # - 금융위원회 Open API (data.go.kr) for LTV/DSR limits
  # - 한국주택금융공사 (HF) for Didimdol/Bogeumjari terms
  # - 주택도시보증공사 (HUG) for Newborn special loan
  #
  # For now, falls back to MockLoanPolicyAdapter behavior
  # until real API credentials are configured.

  def fetch_policies(property_type_code:)
    # TODO: Replace with real API calls when credentials available
    MockLoanPolicyAdapter.new.fetch_policies(property_type_code: property_type_code)
  end
end
