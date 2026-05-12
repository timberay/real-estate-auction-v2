class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair scrivener moving maintenance].freeze

  def self.call(**kwargs) = new(**kwargs).call

  def initialize(available_cash:, reserves_excluding_acquisition_tax:, loan_ratio:,
                 tax_brackets:, acquisition_tax_override: nil)
    @available_cash = available_cash.to_i
    @reserves = reserves_excluding_acquisition_tax
    @loan_ratio = loan_ratio.to_d
    @brackets = tax_brackets
    @override = acquisition_tax_override
  end

  def call
    r = RESERVE_KEYS.sum { |k| @reserves.fetch(k, 0).to_i }

    if @override.nil? && @brackets.empty?
      raise ArgumentError, "tax_brackets must not be empty in auto mode"
    end

    if @override
      tax = @override.to_i
      bid = ((@available_cash - r - tax) / (1 - @loan_ratio)).floor
      rate = nil
    else
      bid, rate = solve_bracket(r)
      tax = (rate * bid).round
    end

    raise InsufficientFundsError if bid <= 0

    Rails.logger.info(
      "[BudgetCalculationService] mode=#{@override ? "override" : "auto"} " \
        "rate=#{rate.inspect} bid=#{bid} tax=#{tax}"
    )

    {
      max_bid_amount: bid,
      acquisition_tax: tax,
      acquisition_tax_rate: rate,
      total_reserves: r + tax,
      breakdown: {
        available_cash: @available_cash,
        repair: @reserves.fetch(:repair, 0).to_i,
        scrivener: @reserves.fetch(:scrivener, 0).to_i,
        moving: @reserves.fetch(:moving, 0).to_i,
        maintenance: @reserves.fetch(:maintenance, 0).to_i,
        acquisition_tax: tax,
        loan_ratio: @loan_ratio.to_f
      }
    }
  end

  private

  def solve_bracket(r)
    @brackets.each do |b|
      rate = b[:rate].to_d
      denom = 1 - @loan_ratio + rate
      candidate = ((@available_cash - r) / denom).floor
      if b[:max].nil? || candidate <= b[:max]
        return [ candidate, rate ]
      end
    end
    raise InsufficientFundsError, "no bracket converged"
  end
end
