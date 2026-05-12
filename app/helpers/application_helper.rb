module ApplicationHelper
  # Formats a price in 만원 units to a human-readable Korean format.
  # Budget settings store values in 만원. Property prices are in 원 (won) —
  # use format_price_won for those.
  #
  # Examples:
  #   format_price_in_eok(5000)   => "5,000만원"
  #   format_price_in_eok(10000)  => "1억"
  #   format_price_in_eok(12000)  => "1억 2,000만원"
  #   format_price_in_eok(85600)  => "8억 5,600만원"
  #   format_price_in_eok(nil)    => "—"
  def format_price_in_eok(amount)
    return "—" unless amount.present? && amount > 0

    eok = amount / 10000
    remainder = amount % 10000

    if eok >= 1 && remainder > 0
      "#{eok}억 #{number_with_delimiter(remainder)}만원"
    elsif eok >= 1
      "#{eok}억"
    else
      "#{number_with_delimiter(amount)}만원"
    end
  end

  # Formats a price in 원 (won) to a human-readable Korean format.
  # Property prices from the court auction API are stored in won.
  #
  # Examples:
  #   format_price_won(800000000)  => "8억"
  #   format_price_won(560000000)  => "5억 6,000만원"
  #   format_price_won(50000000)   => "5,000만원"
  #   format_price_won(nil)        => "—"
  def format_price_won(amount)
    return "—" unless amount.present? && amount > 0

    format_price_in_eok(amount / 10000)
  end

  # Returns the current total number of inspection checklist items.
  # Memoized per request so locale interpolation doesn't trigger N COUNT queries.
  def inspection_item_total
    @_inspection_item_total ||= InspectionItem.count
  end

  # One-line basis explaining how the budget's acquisition_tax was derived.
  # Returns nil when override mode is on or when figures aren't computable.
  def tax_basis_line(setting)
    return nil unless setting&.acquisition_tax_auto?
    return nil if setting.max_bid_amount.to_i.zero? || setting.acquisition_tax.to_i.zero?

    rate_pct = (setting.acquisition_tax.to_d / setting.max_bid_amount.to_d * 100).round(1)
    tier_label = {
      "homeless" => "1세대 무주택",
      "single_home" => "1주택",
      "multi_home_2" => "2주택",
      "multi_home_3plus" => "3주택 이상"
    }.fetch(setting.household_tier, "")
    area_label = setting.area_over_85? ? "전용 85㎡ 초과" : "전용 85㎡ 이하"

    "낙찰가 #{number_with_delimiter(setting.max_bid_amount)}만원 × #{rate_pct}% = " \
      "#{number_with_delimiter(setting.acquisition_tax)}만원 (#{tier_label}, #{area_label})"
  end
end
