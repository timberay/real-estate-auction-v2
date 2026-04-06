class MockRegistryTranscriptAdapter < RegistryTranscriptAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      rights: [
        { type: "근저당", date: "2024-01-15", holder: "국민은행", amount: 216_000_000, status: "active", registry_section: "을구" }
      ],
      tenants: [],
      hug_waiver: false,
      seizures: []
    },
    "2026타경10002" => {
      rights: [
        { type: "근저당", date: "2023-06-01", holder: "신한은행", amount: 180_000_000, status: "active", registry_section: "을구" },
        { type: "가압류", date: "2023-09-15", holder: "채권추심회사", amount: 50_000_000, status: "active", registry_section: "갑구" }
      ],
      tenants: [
        { name: "김임차", deposit: 50_000_000, move_in_date: "2023-03-01", confirmed_date: "2023-03-05", dividend_requested: true, is_small_sum_tenant: false }
      ],
      hug_waiver: false,
      seizures: [
        { type: "압류", date: "2024-01-20", holder: "관할세무서", amount: 8_000_000 }
      ]
    },
    "2026타경10003" => {
      rights: [
        { type: "근저당", date: "2024-05-10", holder: "우리은행", amount: 150_000_000, status: "active", registry_section: "을구" }
      ],
      tenants: [
        { name: "이전세", deposit: 30_000_000, move_in_date: "2024-08-01", confirmed_date: "2024-08-02", dividend_requested: true, is_small_sum_tenant: false }
      ],
      hug_waiver: true,
      seizures: []
    }
  }.freeze

  BANKS = %w[국민은행 신한은행 우리은행 하나은행 농협은행 기업은행 SC제일은행].freeze
  CREDITORS = %w[채권추심회사 자산관리공사 신용보증기금].freeze
  TAX_OFFICES = %w[관할세무서 강남세무서 서초세무서 영등포세무서 마포세무서].freeze
  RIGHT_TYPES = %w[근저당 근저당 근저당 가압류 강제경매개시결정].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_registry(case_number)
  end

  private

  def generate_random_registry(case_number)
    seed = case_number.bytes.each_with_index.sum { |b, i| b * (i + 1) }
    rng = Random.new(seed)

    rights = generate_rights(rng)
    base_date = rights.map { |r| Date.parse(r[:date]) }.min
    tenants = generate_tenants(rng, base_date)
    seizures = generate_seizures(rng, base_date)
    hug_waiver = rng.rand < 0.10

    { rights: rights, tenants: tenants, hug_waiver: hug_waiver, seizures: seizures }
  end

  def generate_rights(rng)
    count = rng.rand(1..3)
    base_year = rng.rand(2020..2025)

    count.times.map do |i|
      type = RIGHT_TYPES[rng.rand(RIGHT_TYPES.size)]
      holder = type == "근저당" ? BANKS[rng.rand(BANKS.size)] : CREDITORS[rng.rand(CREDITORS.size)]
      month = rng.rand(1..12)
      day = rng.rand(1..28)
      date = "#{base_year + i}-#{format('%02d', month)}-#{format('%02d', day)}"
      amount = rng.rand(5..30) * 10_000_000

      {
        type: type,
        date: date,
        holder: holder,
        amount: amount,
        status: "active",
        registry_section: type == "근저당" ? "을구" : "갑구"
      }
    end
  end

  def generate_tenants(rng, base_date)
    return [] if rng.rand >= 0.45

    count = rng.rand(1..2)
    count.times.map do |i|
      days_offset = rng.rand(-180..360)
      move_in = base_date + days_offset
      confirmed = move_in + rng.rand(1..14)
      deposit = rng.rand(2..10) * 5_000_000

      {
        name: "임차인#{rng.rand(100..999)}",
        deposit: deposit,
        move_in_date: move_in.to_s,
        confirmed_date: confirmed.to_s,
        dividend_requested: rng.rand < 0.7,
        is_small_sum_tenant: deposit <= 16_500_000
      }
    end
  end

  def generate_seizures(rng, base_date)
    return [] if rng.rand >= 0.30

    days_after = rng.rand(30..365)
    [{
      type: "압류",
      date: (base_date + days_after).to_s,
      holder: TAX_OFFICES[rng.rand(TAX_OFFICES.size)],
      amount: rng.rand(1..20) * 1_000_000
    }]
  end
end
