module Inspection
  # Lookup service for 주택임대차보호법 §8 / 시행령 §10·§11 소액임차인 최우선변제 보호 한도.
  #
  # Period is selected by the date of the earliest extinguishing 담보물권 (보통 근저당) registered
  # on the property; if no such lien exists, the currently active period applies.
  # Region tier is derived from sido/sigungu against the statutory four-tier classification.
  class SmallTenantProtection
    SEED_PATH = Rails.root.join("db/seeds/small_tenant_priority_table.json").freeze

    # Sigungu that fall inside 수도권정비계획법 과밀억제권역 (capped region 2 of the statute).
    # 인천광역시: 강화군·옹진군 제외. 경기도: 의정부/구리/하남/고양/수원/성남/안양/부천/광명/과천/의왕/군포/시흥/남양주/용인/화성/김포.
    # 세종특별자치시 is treated as 과밀억제권역-equivalent per 시행령 별표 (2018-09-18 revision onward).
    OVERCROWDED_GYEONGGI = %w[
      의정부시 구리시 하남시 고양시 수원시 성남시 안양시 부천시
      광명시 과천시 의왕시 군포시 시흥시 남양주시 용인시 화성시 김포시
    ].freeze

    # Sigungu placed in region 3 (광역시 등 tier) per 시행령 §11: 안산·광주·파주·이천·평택.
    METRO_GYEONGGI = %w[안산시 광주시 파주시 이천시 평택시].freeze

    # sido that map directly to tiers without sigungu disambiguation.
    METRO_SIDO = %w[부산광역시 대구광역시 광주광역시 대전광역시 울산광역시].freeze

    INCHEON_EXCLUDED_FROM_OVERCROWDED = %w[강화군 옹진군].freeze

    def self.lookup(sido:, sigungu:, period_date:)
      tier = classify_tier(sido: sido, sigungu: sigungu)
      period = select_period(period_date)
      return nil unless period

      tier_entry = period["tiers"].find { |t| t["tier"] == tier }
      return nil unless tier_entry

      {
        tier: tier,
        deposit_cap: tier_entry["deposit_cap"].to_i,
        protection_amount: tier_entry["protection_amount"].to_i,
        period_label: period["label"],
        period_starts_on: Date.parse(period["starts_on"]),
        period_ends_on: period["ends_on"].present? ? Date.parse(period["ends_on"]) : nil
      }
    end

    def self.classify_tier(sido:, sigungu:)
      return "seoul" if sido == "서울특별시"
      return "overcrowded" if sido == "세종특별자치시"

      if sido == "인천광역시"
        return "metro" if INCHEON_EXCLUDED_FROM_OVERCROWDED.include?(sigungu.to_s)
        return "overcrowded"
      end

      if sido == "경기도"
        return "overcrowded" if OVERCROWDED_GYEONGGI.include?(sigungu.to_s)
        return "metro" if METRO_GYEONGGI.include?(sigungu.to_s)
        return "other"
      end

      return "metro" if METRO_SIDO.include?(sido.to_s)

      "other"
    end

    def self.periods
      @periods ||= load_periods
    end

    def self.reload!
      @periods = load_periods
    end

    def self.select_period(period_date)
      target = parse_date(period_date) || Date.current
      periods.find do |p|
        starts = Date.parse(p["starts_on"])
        ends = p["ends_on"].present? ? Date.parse(p["ends_on"]) : nil
        target >= starts && (ends.nil? || target <= ends)
      end
    end
    private_class_method :select_period

    def self.parse_date(value)
      return nil if value.nil?
      return value if value.is_a?(Date)
      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
    private_class_method :parse_date

    def self.load_periods
      raw = JSON.parse(File.read(SEED_PATH))
      raw.reject { |entry| entry.key?("_comment") }.freeze
    end
    private_class_method :load_periods
  end
end
