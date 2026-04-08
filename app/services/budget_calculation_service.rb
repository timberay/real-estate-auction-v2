class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair acquisition_tax scrivener moving maintenance].freeze

  def self.call(available_cash:, reserve_funds:, loan_ratio:)
    new(available_cash:, reserve_funds:, loan_ratio:).call
  end

  def initialize(available_cash:, reserve_funds:, loan_ratio:)
    @available_cash = available_cash
    @reserve_funds = reserve_funds
    @loan_ratio = loan_ratio.to_d
  end

  def call
    total_reserves = RESERVE_KEYS.sum { |key| @reserve_funds.fetch(key, 0).to_i }

    raise ArgumentError, "available_cash is required" if @available_cash.nil?

    net_cash = @available_cash - total_reserves
    raise InsufficientFundsError, "Available cash (#{@available_cash}) is less than total reserves (#{total_reserves})" if net_cash <= 0

    divisor = 1 - @loan_ratio
    max_bid_amount = (net_cash / divisor).floor

    {
      total_reserves: total_reserves,
      max_bid_amount: max_bid_amount,
      breakdown: {
        available_cash: @available_cash,
        repair: @reserve_funds.fetch(:repair, 0).to_i,
        acquisition_tax: @reserve_funds.fetch(:acquisition_tax, 0).to_i,
        scrivener: @reserve_funds.fetch(:scrivener, 0).to_i,
        moving: @reserve_funds.fetch(:moving, 0).to_i,
        maintenance: @reserve_funds.fetch(:maintenance, 0).to_i,
        loan_ratio: @loan_ratio.to_f
      }
    }
  end
end
