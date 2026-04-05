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

  def fetch_data(case_number:)
    MOCK_DATA[case_number]
  end
end
