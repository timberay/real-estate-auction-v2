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
end
