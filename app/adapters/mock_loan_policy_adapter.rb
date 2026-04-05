class MockLoanPolicyAdapter < LoanPolicyAdapter
  MOCK_DATA = {
    "apartment" => [
      { policy_name: "경락대출 (1금융)", loan_ratio: 0.8, description: "시중은행 경락대출 — 감정가 기준 LTV 80% (비규제지역 기준)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "경락대출 (2금융)", loan_ratio: 0.9, description: "캐피탈·저축은행 경락대출 — 감정가 기준 LTV 90% (금리 높음)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "villa" => [
      { policy_name: "경락대출 (1금융)", loan_ratio: 0.7, description: "시중은행 경락대출 — 감정가 기준 LTV 70% (비아파트 하향 적용)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "경락대출 (2금융)", loan_ratio: 0.8, description: "캐피탈·저축은행 경락대출 — 감정가 기준 LTV 80% (금리 높음)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "officetel" => [
      { policy_name: "경락대출 (1금융)", loan_ratio: 0.7, description: "시중은행 경락대출 — 감정가 기준 LTV 70% (주거용 인정 시)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "경락대출 (2금융)", loan_ratio: 0.8, description: "캐피탈·저축은행 경락대출 — 감정가 기준 LTV 80% (금리 높음)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ]
  }.freeze

  def fetch_policies(property_type_code:)
    MOCK_DATA.fetch(property_type_code, [])
  end
end
