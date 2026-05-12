# C-4 취득세 산식 재설계 (Acquisition Tax Redesign)

- **Date**: 2026-05-12
- **Owner**: Tonny Donghwi Kim
- **Related**: E2E report C-4 (`docs/e2e-test-report.md:38`), Expert audit (`docs/e2e-test-report.expert.md:36-40`)
- **Status**: Design

## 1. Problem Statement

### Symptom

The onboarding step2 and `/settings/budget` screens compute acquisition tax (취득세) as a static value derived from a hardcoded **average market price** (e.g., 4.8억 for 소형 apartments) multiplied by a per-area tax rate. For a small auction property (e.g., 1,000만원), the system still reports 취득세 = 528만원, which inflates the reserve fund total and pushes the user's max bid price below the floor — effectively blocking the user from bidding on small properties.

### Root cause

`ReserveFundDefault.average_price × acquisition_tax_rate` is computed client-side in `app/javascript/controllers/reserve_fund_controller.js:79` and persisted to `budget_setting.acquisition_tax` (만원). The value has no relationship to the user's actual bid scenario. The downstream max-bid formula `(C − R) / (1 − L)` then deducts an inflated `R` (= 취득세 포함 예비비 합계).

### Intended behavior

Acquisition tax must be a function of the **bid amount**, not a static market average. Because the max-bid formula already depends on reserves (which include tax), the system has a circular dependency that must be resolved deterministically.

## 2. Goals / Non-goals

### Goals

- 취득세 is computed from the (auto-resolved or user-provided) bid amount, not from a static market average.
- 세대 보유 상태 (무주택 / 1주택 / 2주택 / 3주택 이상) is captured during onboarding and influences the tax rate.
- 조정대상지역 (`Regions.regulated?`) and 전용 85㎡ 초과 여부 are folded into the rate lookup.
- The max-bid formula converges in O(1) (closed-form per bracket, ≤3 brackets).
- Onboarding step2 and `/settings/budget` surfaces show the tax 산출 근거 (e.g., `6,540만원 × 1.1% = 72만원, 1세대 무주택, 6억 이하`).
- Existing user data (stored `acquisition_tax` values) is not lost; a migration default flips users into auto mode and the new formula overrides on next page load.

### Non-goals (out of scope; see §10 for follow-ups)

- `ProfitCalculatorComponent` (property show page) is **not** re-wired to the new calculator in this PR. It continues to read `budget_setting.acquisition_tax` (the budget-scenario value).
- `ReserveFundDefault.acquisition_tax_rate` and `average_price` columns are **not** removed in this PR (deprecated, dropped in follow-up F-A).
- Precise 누진 formula `(가액 × 2/3 − 3)/100` for the 6~9억 bracket is replaced by a single representative rate (단순화). Precision upgrade is follow-up F-C.
- 법인 / 임대사업자 / 기타 특수 신분 분기 is left for future scope; 4 household tiers cover the dominant population.

## 3. Formula

### Variables (units: 만원)

- `C` = `available_cash`
- `L` = `loan_ratio` (decimal, 0..1)
- `R` = reserves **excluding** acquisition tax (`repair_cost + scrivener_fee + moving_cost + maintenance_fee`)
- `t` = acquisition tax rate (decimal, depends on bracket and user attributes)
- `B` = `max_bid_amount`
- `T` = acquisition tax (= `round(t · B)`)

### Closed-form (single bracket)

```
B(1 − L) = C − R − T
T = t · B
⇒ B(1 − L + t) = C − R
⇒ B = floor((C − R) / (1 − L + t))
T = round(t · B)
```

### Bracket iteration (≤3 iterations, deterministic)

The rate `t` depends on which bracket `B` falls into (e.g., 주택 무주택: 0~6억 / 6~9억 / 9억 초과). Iterate from the lowest bracket upward:

```
brackets = [
  { rate: 0.011, max: 60_000 },   # 6억 이하
  { rate: 0.022, max: 90_000 },   # 6~9억 (단순화 세율)
  { rate: 0.033, max: nil }       # 9억 초과
]

for b in brackets:
    candidate_B = floor((C − R) / (1 − L + b.rate))
    if b.max is None or candidate_B <= b.max:
        return (B = candidate_B, rate = b.rate)
```

### Monotonicity guarantee

As `b.rate` increases, denominator `(1 − L + b.rate)` increases, so `candidate_B` decreases. Therefore if a candidate exceeds its bracket's max, the next-bracket candidate is strictly smaller — guaranteeing convergence within 3 iterations. No fixed-point loop required.

### Override mode (auto OFF)

When the user disables auto-calc, `T` is the user-supplied value:

```
B = floor((C − R − T_override) / (1 − L))
```

### Numerical examples (verified)

| Case | C | L | R | Result |
|---|---|---|---|---|
| ① Small (bug repro) | 3,000 | 0.7 | 600 | t=0.011 → B=7,717, T≈85 (replaces 528) |
| ② Mid | 30,000 | 0.7 | 1,500 | bracket1 candidate 91,640 > 60,000 → bracket2 → B=88,509, T≈1,947 |
| ③ Large | 100,000 | 0.7 | 2,000 | brackets 1&2 overflow → bracket3 → B=294,294, T≈9,712 |
| ④ Override | 3,000 | 0.7 | 600 | T_override=800 → B=5,333 |

## 4. Data Model

### New: `AcquisitionTaxRate`

Table: `acquisition_tax_rates`

| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `property_type_id` | bigint FK | references `property_types` |
| `household_tier` | string, NOT NULL | enum: `homeless` / `single_home` / `multi_home_2` / `multi_home_3plus` |
| `regulated_region` | boolean, nullable | 조정대상지역. NULL = 무관 (e.g., 오피스텔/상가) |
| `price_bucket_min_manwon` | integer, NOT NULL | 구간 하한 (만원). 0 / 60_000 / 90_000 |
| `price_bucket_max_manwon` | integer, nullable | 구간 상한. NULL = 무한 |
| `area_over_85` | boolean, nullable | 전용 85㎡ 초과. NULL = 비주택(무관) |
| `total_rate` | decimal(5,4), NOT NULL | 취득세 + 지방교육세 + 농특세 합산. 예: 0.0110 |
| `created_at`, `updated_at` | timestamps | |

**Composite index**: `(property_type_id, household_tier, regulated_region, area_over_85)`.

### Modified: `BudgetSetting`

| Column | Type | Notes |
|---|---|---|
| `household_tier` | string, default `"homeless"`, NOT NULL | new; inclusion validation in model |
| `acquisition_tax_auto` | boolean, default `true`, NOT NULL | new; whether auto-calc mode is active |
| `acquisition_tax` | (unchanged) | semantic change: now an override input used only when `acquisition_tax_auto = false` |

### Seed data — `db/seeds/acquisition_tax_rates.json` (~15-20 rows)

Coverage outline (numbers in basis points illustrative):

- 주택 (apartment / villa):
  - 무주택 + 1주택, 0~6억, 85㎡↓ → 1.1%
  - 무주택 + 1주택, 0~6억, 85㎡↑ → 1.3%
  - 무주택 + 1주택, 6~9억, 85㎡↓ → 2.2% (구간 단순화)
  - 무주택 + 1주택, 6~9억, 85㎡↑ → 2.4%
  - 무주택 + 1주택, 9억+, 85㎡↓ → 3.3%
  - 무주택 + 1주택, 9억+, 85㎡↑ → 3.5%
  - 2주택, 비조정 → 1주택과 동일 세율
  - 2주택, 조정 → 8.4% (구간 무관)
  - 3주택+, 비조정 → 8.4%
  - 3주택+, 조정 → 12.4%
- 오피스텔 / 상가 / 토지: `area_over_85 = NULL`, `regulated_region = NULL`, 구간 무관 → 4.6%

### Migration sequence

1. `create_acquisition_tax_rates` — new table + indexes.
2. `add_household_tier_and_acquisition_tax_auto_to_budget_settings` — two columns with defaults.
3. Seed insertion via `db/seeds.rb` (extend existing seed loader pattern).

Existing data: `budget_setting.acquisition_tax` values are preserved. Default `acquisition_tax_auto = true` causes the next page-load/save to overwrite with the auto-calculated value, which is the desired behavior.

## 5. Service Layer

### New: `AcquisitionTaxCalculator`

`app/services/acquisition_tax_calculator.rb`

```ruby
class AcquisitionTaxCalculator
  class RateNotFoundError < StandardError; end

  Result = Data.define(:rate, :tax_manwon, :rate_source)

  def self.call(bid_manwon:, property_type_id:, household_tier:,
                regulated_region:, area_over_85: nil)
    new(bid_manwon:, property_type_id:, household_tier:,
        regulated_region:, area_over_85:).call
  end

  # Returns brackets array (ordered low->high) for the given user attributes,
  # used by BudgetCalculationService for bracket iteration.
  def self.brackets_for(property_type_id:, household_tier:,
                        regulated_region:, area_over_85:)
    # AcquisitionTaxRate
    #   .where(property_type_id:, household_tier:)
    #   .where("regulated_region IS ? OR regulated_region = ?", nil, regulated_region)
    #   .where("area_over_85 IS ? OR area_over_85 = ?", nil, area_over_85)
    #   .order(:price_bucket_min_manwon)
    #   .map { |r| { rate: r.total_rate, max: r.price_bucket_max_manwon } }
  end

  def call
    rate_row = lookup_rate
    raise RateNotFoundError, "no rate for #{lookup_key}" if rate_row.nil?

    tax = (rate_row.total_rate * @bid_manwon).round
    Result.new(rate: rate_row.total_rate, tax_manwon: tax, rate_source: rate_row)
  end

  private

  def lookup_rate
    AcquisitionTaxRate
      .where(property_type_id: @property_type_id, household_tier: @household_tier)
      .where("price_bucket_min_manwon <= ? AND (price_bucket_max_manwon IS NULL OR price_bucket_max_manwon > ?)", @bid_manwon, @bid_manwon)
      .where("regulated_region IS ? OR regulated_region = ?", nil, @regulated_region)
      .where("area_over_85 IS ? OR area_over_85 = ?", nil, @area_over_85)
      .order(Arel.sql("regulated_region IS NULL, area_over_85 IS NULL"))  # specific over wildcard
      .first
  end
end
```

### Modified: `BudgetCalculationService`

New signature:

```ruby
BudgetCalculationService.call(
  available_cash:,                       # 만원
  reserves_excluding_acquisition_tax:,   # hash {repair:, scrivener:, moving:, maintenance:} in 만원
  loan_ratio:,                            # decimal 0..1
  tax_brackets:,                          # [{rate:, max:}, ...] ordered low->high
  acquisition_tax_override: nil           # nil → auto; integer → manual
)
```

Returns:

```ruby
{
  max_bid_amount: Integer,         # 만원
  acquisition_tax: Integer,        # 만원
  acquisition_tax_rate: Decimal,   # selected rate; nil in override mode
  total_reserves: Integer,         # incl. acquisition tax
  breakdown: { ... }
}
```

Errors:

- `InsufficientFundsError` — unchanged. Raised when `available_cash − R ≤ 0`, or when no bracket yields `B > 0`.
- `ArgumentError` — `tax_brackets` empty or malformed (when auto mode).

### Call sites

Both `OnboardingsController#create_step3` and `Settings::BudgetsController#update`:

```ruby
brackets = AcquisitionTaxCalculator.brackets_for(
  property_type_id: @setting.property_type_id,
  household_tier: @setting.household_tier,
  regulated_region: @setting.regulated_region?,
  area_over_85: @setting.area_range_min.to_i >= 85
)

result = BudgetCalculationService.call(
  available_cash: @setting.available_cash,
  reserves_excluding_acquisition_tax: {
    repair: @setting.repair_cost.to_i,
    scrivener: @setting.scrivener_fee.to_i,
    moving: @setting.moving_cost.to_i,
    maintenance: @setting.maintenance_fee.to_i
  },
  loan_ratio: @setting.loan_ratio,
  tax_brackets: brackets,
  acquisition_tax_override: @setting.acquisition_tax_auto? ? nil : @setting.acquisition_tax
)

@setting.acquisition_tax = result[:acquisition_tax] if @setting.acquisition_tax_auto?
@setting.max_bid_amount = result[:max_bid_amount]
```

## 6. UI Surfaces

### Onboarding step2 (`app/views/onboardings/step2.html.erb`)

New field inserted between **부동산 유형** and **관심 면적**:

```
[ 주택 보유 ▾ ]
  ├ 무주택 (현재 집이 없거나 곧 처분)   ← default
  ├ 1주택 (현재 1채 보유)
  ├ 2주택 보유
  └ 3주택 이상
```

Label tooltip: "주택 수가 많을수록 취득세율이 높아집니다 (조정대상지역 2주택 8.4%, 3주택+ 12.4%)".

취득세 input row behavior:

- **자동 모드 (체크 ON)**:
  - input is `readonly` with subdued background.
  - Value is set by client-side bracket iteration on every change to `available_cash`, `loan_ratio`, other reserves, `household_tier`, `regulated_region`, `area_over_85`.
  - Hint text: `"낙찰가 6,540만원 × 1.1% = 72만원 (1세대 무주택, 6억 이하)"`.
- **수동 모드 (체크 OFF)**:
  - input is editable.
  - Hint text: `"직접 입력 모드 — 자동 계산을 켜면 낙찰가에 연동됩니다"`.
  - `acquisition_tax_auto = false` persisted on submit.

### Settings budget show (`app/views/settings/budgets/show.html.erb`)

Same dropdown + same auto/override semantics. The existing `update_region` AJAX endpoint already returns the budget shell; extend it to include refreshed brackets payload in its response so the client can re-run bracket iteration without a full reload.

### Onboarding complete (`app/views/onboardings/complete.html.erb`)

Add a one-line basis under the acquisition tax row:

> 취득세 산출 근거: `6,540만원 × 1.1% = 72만원 (1세대 무주택, 전용 85㎡ 이하, 비조정지역)`

### Client-side (Stimulus `reserve_fund_controller.js`)

- New value: `tax-brackets-value` (Array of `{rate, max}`).
- New value: `loan-ratio-value`.
- `computeAuto()` replaces the previous `Math.round(rate × average_price)` line. Implementation mirrors the Ruby bracket iteration.
- `household_tier` dropdown change triggers `applyDefaults()` recomputation; brackets are pre-serialized at page load for all `(household_tier × area_over_85 × regulated)` combinations relevant to the user's current property_type, avoiding AJAX round-trips.

## 7. Error Handling / Edge Cases

| Case | Handling |
|---|---|
| `AcquisitionTaxRate` lookup miss (e.g., 상가 + 2주택 같은 무의미 조합) | `RateNotFoundError` → controller catches, sets `acquisition_tax_auto = false`, surfaces flash: "취득세 자동 계산이 일시적으로 불가합니다. 직접 입력해주세요" |
| `tax_brackets` empty array | Same as above |
| `available_cash ≤ R` | `InsufficientFundsError` (existing semantics) — flash: "현금이 부족합니다" |
| Bracket iteration where no bracket yields `B > 0` | Same as above (theoretically only when R ≥ C) |
| `household_tier` invalid | model `inclusion` validation → HTTP 422 |
| `acquisition_tax_auto = true` AND `acquisition_tax_override` value submitted | override ignored, auto mode wins |
| `area_range_min` nil (step1-only state, entering settings/budget) | `area_over_85 = false` |
| `region` nil | `regulated_region = false` (matches NULL rows) |
| Negative or absurdly large `acquisition_tax` (override mode) | existing `numericality: >= 0` guard; upper bound out of scope (C-7 covers range validation) |
| Pre-existing user with stored `acquisition_tax = 528` | migration default `acquisition_tax_auto = true` → next save overwrites with auto-calc; switching to override mode restores the stored value |
| Seed missing (`AcquisitionTaxRate.count == 0`) | `brackets_for` returns `[]` → `BudgetCalculationService` raises `ArgumentError` → controller catches and falls back to override. `db/seeds.rb` must include the new seed loader |

## 8. Testing Strategy (TDD)

### `test/services/acquisition_tax_calculator_test.rb` (new)

- 무주택, 50_000 (5억), 85㎡↓ → rate=0.011, tax=550
- 무주택, 70_000 (7억), 85㎡↓ → rate=0.022, tax=1,540
- 무주택, 95_000 (9.5억), 85㎡↑ → rate=0.035, tax=3,325
- 2주택, regulated, 40_000 (4억) → rate=0.084
- 3주택+, 비regulated, 50_000 → rate=0.084
- 3주택+, regulated, 50_000 → rate=0.124
- 오피스텔, 100_000 → rate=0.046
- lookup miss → `RateNotFoundError`
- `area_over_85=nil` matches NULL rows (non-housing)

### `test/services/budget_calculation_service_test.rb` (modify)

- ① C=3_000, L=0.7, R=600, 주택 무주택 brackets → B=7,717, T≈85, rate=0.011
- ② C=30_000, L=0.7, R=1_500 → B=88,509, T=1,947, rate=0.022 (bracket 2 chosen)
- ③ C=100_000, L=0.7, R=2_000 → B=294,294, T≈9,712, rate=0.033 (bracket 3 chosen)
- ④ override: C=3_000, L=0.7, R=600, T_override=800 → B=5,333, rate=nil
- ⑤ Insufficient funds (C=500, R=600) → `InsufficientFundsError`
- ⑥ brackets=[] → `ArgumentError`

### `test/models/budget_setting_test.rb` (modify)

- `household_tier` inclusion validation
- default `"homeless"`
- `acquisition_tax_auto` default `true`

### `test/models/acquisition_tax_rate_test.rb` (new)

- Model validations
- Seed lookup unit tests

### `test/controllers/onboardings_controller_test.rb` (modify)

- step2 POST with `household_tier` → persisted
- step3 POST → `budget_setting.acquisition_tax` matches auto-calc result

### `test/system/onboarding_*_test.rb`

- Small-property regression: C=3,000 + L=70% → max_bid ≥ 6,500 (proves the bug is fixed)
- Auto OFF: input editable, value preserved on save

### Out-of-test (covered by review)

- `ProfitCalculatorComponent` reads stored `acquisition_tax` value → no test change needed in this PR

## 9. Commit Sequence (Tidy First)

| # | Kind | Content |
|---|---|---|
| 1 | structural | migration `create_acquisition_tax_rates` |
| 2 | structural | migration `add_household_tier_and_acquisition_tax_auto_to_budget_settings` |
| 3 | structural | seed `acquisition_tax_rates.json` + `db/seeds.rb` wiring |
| 4 | behavioral (Red) | `AcquisitionTaxCalculator` test |
| 5 | behavioral (Green) | `AcquisitionTaxCalculator` implementation |
| 6 | behavioral (Red) | `BudgetCalculationService` new signature test |
| 7 | behavioral (Green) | `BudgetCalculationService` bracket iteration |
| 8 | behavioral | controllers (`OnboardingsController`, `Settings::BudgetsController`) wire brackets/override + `BudgetSetting` validations |
| 9 | structural | step2 / budget show ERB: household_tier dropdown + readonly UI |
| 10 | behavioral | `reserve_fund_controller.js` client-side bracket iteration |
| 11 | behavioral | system test (small-property regression) |

Commit on every green test or completed refactor. Never mix structural and behavioral changes in one commit.

## 10. Follow-ups (separate PRs)

- **F-A**. Remove `ReserveFundDefault.acquisition_tax_rate` and `average_price` columns + `/api/reserve_fund_defaults` response cleanup. Wait ~2 weeks after this PR merges to be safe.
- **F-B**. Wire `AcquisitionTaxCalculator` into `ProfitCalculatorComponent` (property show page) so per-property tax reflects the property's actual bid.
- **F-C**. Optional precise progressive formula `(가액 × 2/3 − 3)/100` for the 6~9억 bracket when the user opts in.
- **F-D**. Admin UI for editing `AcquisitionTaxRate` rows (yearly tax-law updates without code deploy).

## 11. Observability

- `Rails.logger.info` one line on every `BudgetCalculationService.call` in auto mode: `household_tier`, `selected_rate`, `bracket_index`, `B`.
- Monitor `RateNotFoundError` rate for the first week post-deploy as a seed-coverage signal.

## 12. Decision Summary

| Decision | Value | Rationale |
|---|---|---|
| Formula structure | closed-form + bracket iteration (≤3 iter) | zero extra user input, always monotonically convergent |
| Household-tier input location | onboarding step2 + settings/budget | natural domain flow |
| Rate model | simplified lookup table (one rate per bracket) | precision vs. implementation effort tradeoff |
| Data storage | new `AcquisitionTaxRate` model | seedable / admin-editable on tax-law updates |
| Auto/manual toggle | `acquisition_tax_auto` boolean persisted | state survives reload |
| Basis transparency | one-line 산출 근거 in UI | user trust + domain accuracy |
| Backfill policy | preserve existing `acquisition_tax` values; default to auto | no data loss; auto recalc overwrites on next save |
