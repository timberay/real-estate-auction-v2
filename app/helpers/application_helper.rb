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

  # Returns an array of { round:, limit: } hashes for each failed auction round.
  # limit = floor(max_bid_amount / 0.8^round)
  def appraisal_limits_by_round(max_bid_amount, failed_auction_rounds)
    return [] if max_bid_amount.nil? || failed_auction_rounds < 1

    (1..failed_auction_rounds).map do |round|
      reduction = BigDecimal("0.8")**round
      { round: round, limit: (max_bid_amount / reduction).floor }
    end
  end
end
