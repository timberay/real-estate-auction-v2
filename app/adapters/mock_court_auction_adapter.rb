class MockCourtAuctionAdapter < CourtAuctionAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      case_number: "2026타경10001",
      court_name: "서울중앙지방법원",
      property_type: "아파트",
      address: "서울특별시 강남구 역삼동 100-1",
      appraisal_price: 80000,
      min_bid_price: 56000,
      remarks: "해당사항 없음",
      non_extinguished_rights: [],
      tenants: [],
      separate_land_registry: false,
      lien_reported: false,
      use_approval: true,
      wall_partition_issue: false,
      is_partial_share: false
    },
    "2026타경10002" => {
      case_number: "2026타경10002",
      court_name: "수원지방법원",
      property_type: "빌라",
      address: "경기도 수원시 영통구 200-2",
      appraisal_price: 30000,
      min_bid_price: 21000,
      remarks: "유치권 신고 있음. 법정지상권 성립 가능성 있음.",
      non_extinguished_rights: [ "전세권" ],
      tenants: [
        { name: "김임차", deposit: nil, move_in_date: "2024-03-15", dividend_requested: false }
      ],
      separate_land_registry: true,
      lien_reported: true,
      use_approval: false,
      wall_partition_issue: true,
      is_partial_share: false
    },
    "2026타경10003" => {
      case_number: "2026타경10003",
      court_name: "인천지방법원",
      property_type: "오피스텔",
      address: "인천광역시 연수구 300-3",
      appraisal_price: 25000,
      min_bid_price: 17500,
      remarks: "해당사항 없음",
      non_extinguished_rights: [],
      tenants: [
        { name: "박세입", deposit: 5000, move_in_date: "2025-01-10", dividend_requested: true }
      ],
      separate_land_registry: false,
      lien_reported: false,
      use_approval: true,
      wall_partition_issue: false,
      is_partial_share: true
    }
  }.freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number]
  end
end
