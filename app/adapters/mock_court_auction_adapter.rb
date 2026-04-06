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

  COURTS = [
    "서울중앙지방법원",
    "서울동부지방법원",
    "서울남부지방법원",
    "수원지방법원",
    "인천지방법원",
    "대전지방법원",
    "대구지방법원",
    "부산지방법원",
    "광주지방법원"
  ].freeze

  ADDRESSES_BY_COURT = {
    "서울중앙지방법원" => [ "서울특별시 강남구 역삼동", "서울특별시 서초구 잠원동", "서울특별시 중구 을지로" ],
    "서울동부지방법원" => [ "서울특별시 성동구 행당동", "서울특별시 광진구 화양동", "서울특별시 송파구 문정동" ],
    "서울남부지방법원" => [ "서울특별시 영등포구 여의도동", "서울특별시 강서구 화곡동", "서울특별시 관악구 봉천동" ],
    "수원지방법원"     => [ "경기도 수원시 영통구", "경기도 용인시 기흥구", "경기도 성남시 분당구" ],
    "인천지방법원"     => [ "인천광역시 연수구 송도동", "인천광역시 부평구 부평동", "인천광역시 남동구 구월동" ],
    "대전지방법원"     => [ "대전광역시 서구 둔산동", "대전광역시 유성구 봉명동", "대전광역시 중구 대흥동" ],
    "대구지방법원"     => [ "대구광역시 수성구 범어동", "대구광역시 달서구 월성동", "대구광역시 중구 동인동" ],
    "부산지방법원"     => [ "부산광역시 해운대구 우동", "부산광역시 동래구 온천동", "부산광역시 남구 대연동" ],
    "광주지방법원"     => [ "광주광역시 서구 치평동", "광주광역시 북구 운암동", "광주광역시 남구 주월동" ]
  }.freeze

  PROPERTY_TYPES = [ "아파트", "빌라", "오피스텔" ].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_property(case_number)
  end

  private

  def generate_random_property(case_number)
    rng = Random.new(case_number.bytes.sum)

    court = COURTS[rng.rand(COURTS.size)]
    addresses = ADDRESSES_BY_COURT[court]
    base_address = addresses[rng.rand(addresses.size)]
    address = "#{base_address} #{rng.rand(1..999)}-#{rng.rand(1..99)}"
    property_type = PROPERTY_TYPES[rng.rand(PROPERTY_TYPES.size)]

    appraisal_price = (rng.rand(10..200) * 1000)
    min_bid_price = (appraisal_price * (rng.rand(60..80) / 100.0)).to_i

    lien_reported = rng.rand < 0.15
    has_tenant = rng.rand < 0.40
    separate_land = rng.rand < 0.20
    use_approval = rng.rand < 0.85
    wall_issue = rng.rand < 0.10
    partial_share = rng.rand < 0.05

    tenants = if has_tenant
      [{
        name: "임차인#{rng.rand(100..999)}",
        deposit: rng.rand(2) == 0 ? nil : rng.rand(1..10) * 1000,
        move_in_date: "202#{rng.rand(3..5)}-#{format('%02d', rng.rand(1..12))}-#{format('%02d', rng.rand(1..28))}",
        dividend_requested: rng.rand < 0.5
      }]
    else
      []
    end

    non_extinguished = lien_reported ? [ "전세권" ] : []

    {
      case_number: case_number,
      court_name: court,
      property_type: property_type,
      address: address,
      appraisal_price: appraisal_price,
      min_bid_price: min_bid_price,
      remarks: lien_reported ? "유치권 신고 있음." : "해당사항 없음",
      non_extinguished_rights: non_extinguished,
      tenants: tenants,
      separate_land_registry: separate_land,
      lien_reported: lien_reported,
      use_approval: use_approval,
      wall_partition_issue: wall_issue,
      is_partial_share: partial_share
    }
  end
end
