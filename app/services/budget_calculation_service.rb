class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair scrivener moving maintenance].freeze

  # F-C-2 — precise progressive formula `(가액(억) × 2/3 − 3)/100` constants.
  # The 6~9억 bracket in housing rates spans these manwon boundaries; inside
  # that range, in precise mode, the rate becomes a function of the bid and
  # `solve_bracket` falls through to the quadratic solver below.
  PRECISE_BRACKET_MAX_MANWON = 90_000
  # r(B) = B / 1_500_000 − 0.03 — derived from (B/10000 × 2/3 − 3)/100.
  PRECISE_RATE_SLOPE_DENOMINATOR = 1_500_000
  PRECISE_RATE_INTERCEPT = 0.03
  # 농어촌특별세 surcharge for over-85 properties; preserved as a flat delta
  # so the precise formula keeps the under-/over-85 split that the seed
  # table embeds via separate rows.
  PRECISE_AREA_OVER_85_SURCHARGE = 0.002

  def self.call(**kwargs) = new(**kwargs).call

  def initialize(available_cash:, reserves_excluding_acquisition_tax:, loan_ratio:,
                 tax_brackets:, acquisition_tax_override: nil,
                 precise_mode: false, area_over_85: false)
    @available_cash = available_cash.to_i
    @reserves = reserves_excluding_acquisition_tax
    @loan_ratio = loan_ratio.to_d
    @brackets = tax_brackets
    @override = acquisition_tax_override
    @precise_mode = precise_mode
    @area_over_85 = area_over_85
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
      if @precise_mode && b[:max] == PRECISE_BRACKET_MAX_MANWON
        bid, rate = solve_precise_quadratic(r)
        return [ bid, rate ] if bid && bid <= PRECISE_BRACKET_MAX_MANWON
        next
      end

      rate = b[:rate].to_d
      denom = 1 - @loan_ratio + rate
      candidate = ((@available_cash - r) / denom).floor
      return [ candidate, rate ] if b[:max].nil? || candidate <= b[:max]
    end
    raise InsufficientFundsError, "no bracket converged"
  end

  # Closed-form solver for the precise progressive rate inside the 6~9억
  # bracket: r(B) = B/1_500_000 − 0.03 (+ surcharge). The equation
  # `(1 − L)B + r(B)B + R = A` becomes quadratic in B; the positive root is
  # the unique physically meaningful solution.
  def solve_precise_quadratic(r)
    surcharge = @area_over_85 ? PRECISE_AREA_OVER_85_SURCHARGE : 0.0
    a_coef = 1.0 / PRECISE_RATE_SLOPE_DENOMINATOR
    b_coef = 1 - @loan_ratio.to_f - PRECISE_RATE_INTERCEPT + surcharge
    c_coef = -(@available_cash - r).to_f

    discriminant = (b_coef**2) - (4 * a_coef * c_coef)
    return [ nil, nil ] if discriminant.negative?

    bid = ((-b_coef + Math.sqrt(discriminant)) / (2 * a_coef)).floor
    rate = (bid.to_d / PRECISE_RATE_SLOPE_DENOMINATOR) - PRECISE_RATE_INTERCEPT.to_d + surcharge.to_d
    [ bid, rate ]
  end
end
