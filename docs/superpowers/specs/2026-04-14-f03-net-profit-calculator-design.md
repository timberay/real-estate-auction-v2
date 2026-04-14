# F03 Net Profit Calculator — Design Spec

## 1. Overview

A client-side profit estimation tool for pre-bid decision making. Users adjust expected bid price via slider and enter expected sale price to see an itemized cost breakdown and net profit in real time.

This is a rough estimation tool — not a tax calculator. All tax figures use simplified effective tax rates with prominent disclaimers.

### Scope

- Add `ProfitCalculatorComponent` to the grade report page
- Add `profit_calculator_controller.js` Stimulus controller for real-time calculation
- No server-side calculation, no data persistence, no PDF inclusion

### Out of Scope

- Reverse calculation (target profit → max bid) — replaced by slider interaction
- Property tax / comprehensive real estate tax — too small to matter for rough estimation
- Brokerage commission — excluded for simplicity
- Corporate / real estate trader ownership types — show "별도 계산 필요" message
- PDF export of calculator results — calculator is a screen-only interactive tool
- Data persistence — inputs are not saved, user re-enters each time

---

## 2. Location in Report

Inserted into the grade report page (`show.html.erb`) directly after `BidOpinionComponent`:

```
PropertyInfoComponent
ReportBudgetComponent
GradeSummaryComponent
BidOpinionComponent
★ ProfitCalculatorComponent
TabSummaryTableComponent
RiskItemsListComponent
RightsReportSectionComponent
...
```

Not included in `show.pdf.erb` — the PDF already contains BidOpinionComponent with key figures.

---

## 3. User Inputs

| Input | UI Control | Default | Range |
|-------|-----------|---------|-------|
| Expected bid price | Slider + number input | `property.min_bid_price` | min_bid_price ~ appraisal_price × 1.2 |
| Expected sale price | Number input | empty (required) | Free input |
| Ownership type | Radio buttons (3) | 무주택 | 무주택 / 1주택 / 다주택 |
| Holding period | Radio buttons (3) | 2년 이상 | 1년 미만 / 1~2년 / 2년 이상 |

**Layout:** 2×2 grid. Top row: bid price slider + sale price input. Bottom row: ownership radio + holding period radio.

**Slider behavior:**
- Dragging slider updates number input; typing in number input updates slider position
- Below slider: min label, "감정가의 N%" indicator, max label
- Follows `budget_calculator_controller.js` patterns for `fieldValue` / `updateDisplay`

**Non-individual notice:** Below ownership radio: "법인/매매업자는 별도의 세금 계산이 필요합니다" in small muted text.

---

## 4. Calculation Formula

All amounts in 만원 (10,000 KRW).

```
total_investment = bid_price + assumed_amount
acquisition_tax = bid_price × acquisition_tax_rate(ownership)
acquisition_costs = acquisition_tax + scrivener_fee + repair_cost + moving_cost + maintenance_fee
capital_gain = sale_price - total_investment - acquisition_costs
capital_gains_tax = max(0, capital_gain × cgt_rate(ownership, holding_period))
net_profit = sale_price - total_investment - acquisition_costs - capital_gains_tax
roi_percent = net_profit / total_investment × 100
```

**Data sources:**
- `bid_price` — user slider input
- `sale_price` — user manual input
- `assumed_amount` — from `RightsAnalysisReport.assumed_amount` (0 if no report)
- `scrivener_fee`, `repair_cost`, `moving_cost`, `maintenance_fee` — from `BudgetSetting` reserve fields
- Tax rates — JS constants (see section 5)

**Edge cases:**
- If `sale_price` is empty: show "매도가를 입력하세요" instead of results
- If `capital_gain` ≤ 0: capital gains tax = 0, net profit shown in red
- If net profit < 0: summary cards switch from green to red styling

---

## 5. Effective Tax Rate Tables

Simplified rates stored as JS constants in the Stimulus controller. These are approximations for rough estimation.

### Acquisition Tax

| Ownership | Rate | Note |
|-----------|------|------|
| 무주택 | 1.1% | Standard rate (residential ≤ 6억) |
| 1주택 | 1.1% | Same |
| 다주택 | 8.4% | Surcharge (2-home) |

### Capital Gains Tax

| Ownership | < 1 year | 1–2 years | 2+ years |
|-----------|----------|-----------|----------|
| 무주택 | 70% | 60% | 20% |
| 1주택 | 70% | 60% | 0% |
| 다주택 | 70% | 60% | 40% |

**Notes:**
- 1주택 2년+ = 0% assumes 9억 이하 비과세 (most auction properties qualify)
- 무주택 2년+ = 20% is a mid-range estimate of progressive rates (6–45%)
- 다주택 2년+ = 40% includes base rate + 20%p surcharge
- Short-term rates (< 1yr: 70%, 1–2yr: 60%) are statutory flat rates

---

## 6. Result UI

### Summary Cards (4-column grid)

| Card | Value | Color |
|------|-------|-------|
| 총 투자비용 | total_investment | neutral (slate) |
| 총 비용 | acquisition_costs + capital_gains_tax | red |
| 순수익 | net_profit | green (positive) / red (negative) |
| 수익률 | roi_percent | green (positive) / red (negative) |

### Itemized Breakdown Table

| Row | Amount | Note |
|-----|--------|------|
| 매도가 | +sale_price | 사용자 입력 |
| **(-) 차감 항목** | | |
| 낙찰가 | -bid_price | 슬라이더 입력 |
| 인수금액 | -assumed_amount | 권리분석 결과 |
| 취득세 | -acquisition_tax | 추정 ~N% |
| 법무사비 | -scrivener_fee | 예산 설정값 |
| 수선비 | -repair_cost | 예산 설정값 |
| 이사비(명도비) | -moving_cost | 예산 설정값 |
| 미납 관리비 | -maintenance_fee | 예산 설정값 |
| 양도소득세 | -capital_gains_tax | 추정 ~N% |
| **순수익** | **=net_profit** | **수익률 N%** |

### Disclaimers (3 locations)

1. **Component title badge:** "추정치 — 세무사 상담을 권장합니다"
2. **Tax note columns:** "추정 ~N%" in the breakdown table's note column for acquisition tax and capital gains tax rows
3. **Bottom disclaimer block:** "이 계산은 추정치이며 실제 세금과 다를 수 있습니다. 정확한 세금은 세무사에게 상담하세요. 양도소득세는 소유형태와 보유기간에 따른 실효세율로 간이 계산한 값입니다."

---

## 7. File Structure

| File | Role |
|------|------|
| `app/components/profit_calculator_component.rb` | ViewComponent — passes property, budget_setting, report data as data attributes |
| `app/components/profit_calculator_component.html.erb` | Input UI + result table template |
| `app/javascript/controllers/profit_calculator_controller.js` | Real-time calculation, slider sync, result rendering |

### Component Interface

```ruby
ProfitCalculatorComponent.new(
  property: @property,
  budget_setting: @budget_setting,
  report: @report
)
```

The component renders data attributes on the root element for the Stimulus controller to read:

- `data-profit-calculator-min-bid-value` — property.min_bid_price (만원)
- `data-profit-calculator-appraisal-value` — property.appraisal_price (만원)
- `data-profit-calculator-assumed-amount-value` — report&.assumed_amount || 0 (만원)
- `data-profit-calculator-scrivener-fee-value` — budget_setting&.scrivener_fee || 0
- `data-profit-calculator-repair-cost-value` — budget_setting&.repair_cost || 0
- `data-profit-calculator-moving-cost-value` — budget_setting&.moving_cost || 0
- `data-profit-calculator-maintenance-fee-value` — budget_setting&.maintenance_fee || 0

### Controller/View Changes

- `GradesController#show` — no changes needed (already loads all required data)
- `show.html.erb` — add one `render` line after BidOpinionComponent
- `show.pdf.erb` — no changes (calculator excluded from PDF)

---

## 8. Testing Strategy

### Component Tests (Minitest)

- **ProfitCalculatorComponent:** Renders with property + budget_setting + report; renders without budget_setting (nil fallback); renders without report (nil fallback); displays disclaimer text
- **Data attributes:** Correct values passed from models to data attributes

### Stimulus Controller Tests

Not in scope for MVP — tax rate logic is simple constant lookup + arithmetic. Validated via E2E.

### E2E Tests (Playwright)

- Slider changes bid price → result table updates
- Type sale price → results appear
- Switch ownership type → tax amounts change
- Switch holding period → capital gains tax changes
- Negative profit → red styling
- Empty sale price → shows prompt message
- Disclaimer text is visible

---

## 9. SRS Impact

This implementation covers F03 acceptance criteria with modifications:

- [x] ~~All 5 ownership types~~ → 3 individual ownership types (법인/매매업자 excluded with message)
- [x] ~~Reverse mode~~ → Replaced by slider-based forward calculation
- [x] Itemized breakdown shows every deduction line item
- [x] Tax disclaimer displayed on every calculation result

After this work:
- **F03: Complete** (with documented scope reductions)
- Remaining: F06 (P2, Eviction Guide)
