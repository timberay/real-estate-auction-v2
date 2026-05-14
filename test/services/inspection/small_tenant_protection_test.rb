require "test_helper"

class Inspection::SmallTenantProtectionTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Period selection — based on earliest extinguishing 근저당 설정일
  # ---------------------------------------------------------------------------
  test "applies the currently active period when period_date is nil" do
    result = Inspection::SmallTenantProtection.lookup(sido: "서울특별시", sigungu: nil, period_date: nil)
    assert_equal "seoul", result[:tier]
    assert_equal 165_000_000, result[:deposit_cap]
    assert_equal 55_000_000, result[:protection_amount]
    assert_match(/2023-02-21/, result[:period_label])
  end

  test "applies the 2021-05-11~2023-02-20 period when 근저당 date falls in that window" do
    result = Inspection::SmallTenantProtection.lookup(
      sido: "서울특별시", sigungu: nil, period_date: Date.new(2022, 6, 1)
    )
    assert_equal 150_000_000, result[:deposit_cap]
    assert_equal 50_000_000, result[:protection_amount]
  end

  test "applies the 2018-09-18~2021-05-10 period at the boundary" do
    boundary_start = Inspection::SmallTenantProtection.lookup(
      sido: "서울특별시", sigungu: nil, period_date: Date.new(2018, 9, 18)
    )
    assert_equal 110_000_000, boundary_start[:deposit_cap]

    boundary_end = Inspection::SmallTenantProtection.lookup(
      sido: "서울특별시", sigungu: nil, period_date: Date.new(2021, 5, 10)
    )
    assert_equal 110_000_000, boundary_end[:deposit_cap]
  end

  test "returns nil when period_date is before the oldest table entry (2014-01-01)" do
    result = Inspection::SmallTenantProtection.lookup(
      sido: "서울특별시", sigungu: nil, period_date: Date.new(2013, 12, 31)
    )
    assert_nil result
  end

  test "accepts String dates and parses to Date" do
    result = Inspection::SmallTenantProtection.lookup(
      sido: "서울특별시", sigungu: nil, period_date: "2024-01-15"
    )
    assert_equal 165_000_000, result[:deposit_cap]
  end

  # ---------------------------------------------------------------------------
  # Region tier classification
  # ---------------------------------------------------------------------------
  test "서울특별시 → seoul tier" do
    result = Inspection::SmallTenantProtection.lookup(sido: "서울특별시", sigungu: "강남구", period_date: nil)
    assert_equal "seoul", result[:tier]
  end

  test "경기도 수원시 → overcrowded tier (수도권정비계획법 과밀억제권역 시 중 하나)" do
    result = Inspection::SmallTenantProtection.lookup(sido: "경기도", sigungu: "수원시", period_date: nil)
    assert_equal "overcrowded", result[:tier]
    assert_equal 145_000_000, result[:deposit_cap]
  end

  test "경기도 안산시 → metro tier (시행령 §11 ②3 안산·광주·파주·이천·평택 분류)" do
    result = Inspection::SmallTenantProtection.lookup(sido: "경기도", sigungu: "안산시", period_date: nil)
    assert_equal "metro", result[:tier]
    assert_equal 85_000_000, result[:deposit_cap]
  end

  test "인천광역시 일반 → overcrowded tier" do
    result = Inspection::SmallTenantProtection.lookup(sido: "인천광역시", sigungu: "남동구", period_date: nil)
    assert_equal "overcrowded", result[:tier]
  end

  test "인천광역시 강화군/옹진군 → metro tier (과밀억제권역에서 제외)" do
    ganghwa = Inspection::SmallTenantProtection.lookup(sido: "인천광역시", sigungu: "강화군", period_date: nil)
    ongjin = Inspection::SmallTenantProtection.lookup(sido: "인천광역시", sigungu: "옹진군", period_date: nil)
    assert_equal "metro", ganghwa[:tier]
    assert_equal "metro", ongjin[:tier]
  end

  test "부산광역시 일반 → metro tier" do
    result = Inspection::SmallTenantProtection.lookup(sido: "부산광역시", sigungu: "해운대구", period_date: nil)
    assert_equal "metro", result[:tier]
    assert_equal 85_000_000, result[:deposit_cap]
  end

  test "세종특별자치시 → overcrowded tier (시행령 별표 명시)" do
    result = Inspection::SmallTenantProtection.lookup(sido: "세종특별자치시", sigungu: nil, period_date: nil)
    assert_equal "overcrowded", result[:tier]
  end

  test "강원도 → other tier" do
    result = Inspection::SmallTenantProtection.lookup(sido: "강원도", sigungu: "춘천시", period_date: nil)
    assert_equal "other", result[:tier]
    assert_equal 75_000_000, result[:deposit_cap]
    assert_equal 25_000_000, result[:protection_amount]
  end

  test "충청남도 → other tier" do
    result = Inspection::SmallTenantProtection.lookup(sido: "충청남도", sigungu: "천안시", period_date: nil)
    assert_equal "other", result[:tier]
  end

  test "blank sido falls back to other tier (defensive — should still answer)" do
    result = Inspection::SmallTenantProtection.lookup(sido: nil, sigungu: nil, period_date: nil)
    assert_equal "other", result[:tier]
  end

  # ---------------------------------------------------------------------------
  # Period × tier combination
  # ---------------------------------------------------------------------------
  test "경기도 수원시 (overcrowded) × 2017 (2016-03-31~2018-09-17) → 8000만/2700만" do
    result = Inspection::SmallTenantProtection.lookup(
      sido: "경기도", sigungu: "수원시", period_date: Date.new(2017, 5, 1)
    )
    assert_equal 80_000_000, result[:deposit_cap]
    assert_equal 27_000_000, result[:protection_amount]
  end

  test "result includes period label and date range fields" do
    result = Inspection::SmallTenantProtection.lookup(sido: "서울특별시", sigungu: nil, period_date: nil)
    assert_kind_of String, result[:period_label]
    assert_kind_of Date, result[:period_starts_on]
    # Current period has no end (nil)
    assert_nil result[:period_ends_on]
  end
end
