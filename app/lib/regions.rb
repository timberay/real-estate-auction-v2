module Regions
  # Canonical list of Korean administrative regions (시/도 level) the app
  # supports. Used by the budget UI region picker, the court auction
  # filter, and the LTV regulation lookup.
  ALL = [
    "서울특별시", "부산광역시", "대구광역시", "인천광역시", "광주광역시",
    "대전광역시", "울산광역시", "세종특별자치시", "경기도", "강원도",
    "충청북도", "충청남도", "전라북도", "전라남도", "경상북도",
    "경상남도", "제주특별자치도", "강원특별자치도", "전북특별자치도"
  ].freeze

  # Fallback region when the user hasn't picked one (smallest market —
  # search returns quickly, useful for default-state UX).
  DEFAULT = "제주특별자치도".freeze

  # Regions where LTV regulation applies (banks must offer the lower
  # `regulated_loan_ratio` instead of the standard `loan_ratio`).
  REGULATED = [ "서울특별시" ].freeze

  # Region name → court auction site filter code (rdnmSdCd).
  CODES = {
    "서울특별시" => "11", "부산광역시" => "26", "대구광역시" => "27",
    "인천광역시" => "28", "광주광역시" => "29", "대전광역시" => "30",
    "울산광역시" => "31", "세종특별자치시" => "36", "경기도" => "41",
    "강원도" => "42", "충청북도" => "43", "충청남도" => "44",
    "전라북도" => "45", "전라남도" => "46", "경상북도" => "47",
    "경상남도" => "48", "제주특별자치도" => "50",
    "강원특별자치도" => "51", "전북특별자치도" => "52"
  }.freeze

  module_function

  # Resolves the court auction filter code from a free-text address by
  # matching the leading region name (e.g. "서울특별시 강남구..." → "11").
  def code_for(address)
    return nil if address.blank?
    CODES.find { |name, _| address.start_with?(name) }&.last
  end

  def regulated?(name)
    REGULATED.include?(name)
  end
end
