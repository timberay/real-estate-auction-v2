class MockBuildingLedgerAdapter < BuildingLedgerAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      usage_type: "아파트",
      violation_flag: false,
      completion_date: "2015-06-20",
      room_count: 3,
      floor_info: "5층",
      parking_per_unit: 1.2,
      total_units: 200
    },
    "2026타경10002" => {
      usage_type: "근린생활시설",
      violation_flag: true,
      completion_date: "2025-03-01",
      room_count: 1,
      floor_info: "반지하",
      parking_per_unit: 0.3,
      total_units: 12
    },
    "2026타경10003" => {
      usage_type: "사무소",
      violation_flag: false,
      completion_date: "2020-11-15",
      room_count: 1,
      floor_info: "8층",
      parking_per_unit: 0.8,
      total_units: 50
    }
  }.freeze

  USAGE_TYPES = [ "아파트", "빌라", "오피스텔", "근린생활시설", "사무소" ].freeze

  FLOOR_PREFIXES = [ "", "지상 " ].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_building_data(case_number)
  end

  private

  def generate_random_building_data(case_number)
    rng = Random.new(case_number.bytes.sum + 1)

    usage_type = USAGE_TYPES[rng.rand(USAGE_TYPES.size)]
    violation_flag = rng.rand < 0.15

    year = rng.rand(2000..2024)
    month = rng.rand(1..12)
    day = rng.rand(1..28)
    completion_date = "#{year}-#{format('%02d', month)}-#{format('%02d', day)}"

    room_count = case usage_type
    when "아파트", "빌라" then rng.rand(2..4)
    when "오피스텔" then 1
    else rng.rand(1..3)
    end

    floor_num = rng.rand(1..20)
    use_basement = rng.rand < 0.05
    floor_info = use_basement ? "반지하" : "#{floor_num}층"

    parking_per_unit = (rng.rand(3..15) / 10.0).round(1)

    total_units = case usage_type
    when "아파트" then rng.rand(50..500)
    when "빌라" then rng.rand(6..30)
    when "오피스텔" then rng.rand(20..200)
    else rng.rand(5..50)
    end

    {
      usage_type: usage_type,
      violation_flag: violation_flag,
      completion_date: completion_date,
      room_count: room_count,
      floor_info: floor_info,
      parking_per_unit: parking_per_unit,
      total_units: total_units
    }
  end
end
