class MockLoanPolicyAdapter < LoanPolicyAdapter
  MOCK_DATA = {
    "apartment" => [
      { policy_name: "디딤돌 대출", loan_ratio: 0.8, description: "무주택 서민 주거안정을 위한 정책 모기지 (소득 6천만원 이하, 주택가격 5억원 이하)", source_url: "https://www.hf.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "일반 주담대", loan_ratio: 0.7, description: "일반 주택담보대출 (규제지역 LTV 기준)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "신생아특례", loan_ratio: 0.8, description: "출산가구 주거지원 특례대출 (2년 내 출산, 소득 1.3억 이하)", source_url: "https://www.hug.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "villa" => [
      { policy_name: "디딤돌 대출", loan_ratio: 0.7, description: "무주택 서민 주거안정을 위한 정책 모기지 (빌라 LTV 하향)", source_url: "https://www.hf.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "일반 주담대", loan_ratio: 0.6, description: "빌라 담보대출 (감정가 대비, 금융기관별 상이)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "officetel" => [
      { policy_name: "일반 주담대", loan_ratio: 0.6, description: "오피스텔 담보대출 (주거용 인정 시)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "사업자 대출", loan_ratio: 0.7, description: "사업자 등록 시 사업용 담보대출 가능", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ]
  }.freeze

  def fetch_policies(property_type_code:)
    MOCK_DATA.fetch(property_type_code, [])
  end
end
