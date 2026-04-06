module ApplicationHelper
  # Formats a price in 만원 units to a human-readable Korean format.
  # DB stores values in 만원. Display converts to 억 when >= 10,000.
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
end
