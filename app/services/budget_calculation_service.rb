class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair acquisition_tax scrivener moving maintenance].freeze
  PRICE_REDUCTION_PER_ROUND = 0.8

  def self.call(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:)
    new(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:).call
  end

  def initialize(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:)
    @available_cash = available_cash
    @reserve_funds = reserve_funds
    @loan_ratio = loan_ratio.to_d
    @failed_auction_rounds = failed_auction_rounds
  end

  def call
    total_reserves = RESERVE_KEYS.sum { |key| @reserve_funds.fetch(key, 0).to_i }

    net_cash = @available_cash - total_reserves
    raise InsufficientFundsError, "Available cash (#{@available_cash}) is less than total reserves (#{total_reserves})" if net_cash <= 0

    divisor = 1 - @loan_ratio
    max_bid_amount = (net_cash / divisor).floor

    searchable_appraisal_limit = if @failed_auction_rounds > 0
      reduction_factor = PRICE_REDUCTION_PER_ROUND**@failed_auction_rounds
      (max_bid_amount / reduction_factor).floor
    else
      max_bid_amount
    end

    {
      total_reserves: total_reserves,
      max_bid_amount: max_bid_amount,
      searchable_appraisal_limit: searchable_appraisal_limit,
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
