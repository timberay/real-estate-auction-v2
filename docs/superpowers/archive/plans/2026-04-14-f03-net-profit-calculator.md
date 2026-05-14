# F03 Net Profit Calculator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a client-side profit estimation calculator to the grade report page so users can see estimated net profit before bidding.

**Architecture:** A single ViewComponent (`ProfitCalculatorComponent`) renders input controls and a result table. A Stimulus controller (`profit_calculator_controller.js`) handles all calculation logic client-side using simplified effective tax rate constants. No server-side calculation, no data persistence, no PDF inclusion.

**Tech Stack:** Ruby on Rails 8.1, ViewComponent, Stimulus (pure JS), TailwindCSS

**Spec:** `docs/superpowers/specs/2026-04-14-f03-net-profit-calculator-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `app/components/profit_calculator_component.rb` | Create | ViewComponent — accepts property, budget_setting, report; exposes data attributes in 만원 |
| `app/components/profit_calculator_component.html.erb` | Create | Input UI (slider, number inputs, radios) + result table + disclaimers |
| `app/javascript/controllers/profit_calculator_controller.js` | Create | Real-time calculation, slider↔input sync, result rendering, tax rate constants |
| `app/views/inspections/grades/show.html.erb` | Modify (line 6) | Add `render ProfitCalculatorComponent` after BidOpinionComponent |
| `test/components/profit_calculator_component_test.rb` | Create | ViewComponent unit tests |

---

### Task 1: ProfitCalculatorComponent — Ruby class with data attributes

**Files:**
- Create: `app/components/profit_calculator_component.rb`
- Create: `test/components/profit_calculator_component_test.rb`

- [ ] **Step 1: Write the failing test — renders with all data**

Create `test/components/profit_calculator_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class ProfitCalculatorComponentTest < ViewComponent::TestCase
  setup do
    @property = properties(:safe_apartment)
    @budget = budget_settings(:completed)
    @report = rights_analysis_reports(:safe_apartment_report)
  end

  test "renders with all data and correct data attributes" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    # Property values converted from 원 to 만원
    assert_selector "[data-profit-calculator-min-bid-value='56000']"
    assert_selector "[data-profit-calculator-appraisal-value='80000']"
    # Report assumed_amount already in 만원
    assert_selector "[data-profit-calculator-assumed-amount-value='0']"
    # Budget reserves already in 만원
    assert_selector "[data-profit-calculator-scrivener-fee-value='80']"
    assert_selector "[data-profit-calculator-repair-cost-value='500']"
    assert_selector "[data-profit-calculator-moving-cost-value='150']"
    assert_selector "[data-profit-calculator-maintenance-fee-value='50']"
  end

  test "renders disclaimer badge" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    assert_text "추정치"
    assert_text "세무사 상담을 권장합니다"
  end

  test "renders with nil budget_setting using zero defaults" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    assert_selector "[data-profit-calculator-scrivener-fee-value='0']"
    assert_selector "[data-profit-calculator-repair-cost-value='0']"
    assert_selector "[data-profit-calculator-moving-cost-value='0']"
    assert_selector "[data-profit-calculator-maintenance-fee-value='0']"
  end

  test "renders with nil report using zero assumed_amount" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: nil
    ))

    assert_selector "[data-profit-calculator-assumed-amount-value='0']"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/profit_calculator_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant ProfitCalculatorComponent`

- [ ] **Step 3: Write minimal implementation**

Create `app/components/profit_calculator_component.rb`:

```ruby
# frozen_string_literal: true

class ProfitCalculatorComponent < ViewComponent::Base
  def initialize(property:, budget_setting:, report:)
    @property = property
    @budget = budget_setting
    @report = report
  end

  # All values normalized to 만원 for the Stimulus controller
  def min_bid_manwon
    @property.min_bid_price.to_i / 10000
  end

  def appraisal_manwon
    @property.appraisal_price.to_i / 10000
  end

  def assumed_amount
    @report&.assumed_amount.to_i
  end

  def scrivener_fee
    @budget&.scrivener_fee.to_i
  end

  def repair_cost
    @budget&.repair_cost.to_i
  end

  def moving_cost
    @budget&.moving_cost.to_i
  end

  def maintenance_fee
    @budget&.maintenance_fee.to_i
  end
end
```

Create a minimal `app/components/profit_calculator_component.html.erb` (just enough to pass the test — full UI comes in Task 2):

```erb
<div data-controller="profit-calculator"
     data-profit-calculator-min-bid-value="<%= min_bid_manwon %>"
     data-profit-calculator-appraisal-value="<%= appraisal_manwon %>"
     data-profit-calculator-assumed-amount-value="<%= assumed_amount %>"
     data-profit-calculator-scrivener-fee-value="<%= scrivener_fee %>"
     data-profit-calculator-repair-cost-value="<%= repair_cost %>"
     data-profit-calculator-moving-cost-value="<%= moving_cost %>"
     data-profit-calculator-maintenance-fee-value="<%= maintenance_fee %>"
     class="space-y-4">
  <div class="flex items-center gap-3">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">순수익 계산기</h3>
    <span class="text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-2 py-1 rounded">추정치 — 세무사 상담을 권장합니다</span>
  </div>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/profit_calculator_component_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/components/profit_calculator_component.rb \
        app/components/profit_calculator_component.html.erb \
        test/components/profit_calculator_component_test.rb
git commit -m "feat(f03): add ProfitCalculatorComponent with data attributes

Red-green: component passes property/budget/report data as
만원-normalized data attributes for the Stimulus controller."
```

---

### Task 2: ProfitCalculatorComponent — Full input UI template

**Files:**
- Modify: `app/components/profit_calculator_component.html.erb`

- [ ] **Step 1: Replace the minimal template with the full input + result UI**

Replace `app/components/profit_calculator_component.html.erb` with the complete template. The root `<div>` keeps the same data attributes from Task 1. Inside it:

```erb
<div data-controller="profit-calculator"
     data-profit-calculator-min-bid-value="<%= min_bid_manwon %>"
     data-profit-calculator-appraisal-value="<%= appraisal_manwon %>"
     data-profit-calculator-assumed-amount-value="<%= assumed_amount %>"
     data-profit-calculator-scrivener-fee-value="<%= scrivener_fee %>"
     data-profit-calculator-repair-cost-value="<%= repair_cost %>"
     data-profit-calculator-moving-cost-value="<%= moving_cost %>"
     data-profit-calculator-maintenance-fee-value="<%= maintenance_fee %>"
     class="space-y-4">

  <%# ===== Title + Disclaimer Badge ===== %>
  <div class="flex items-center gap-3">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">순수익 계산기</h3>
    <span class="text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-2 py-1 rounded">추정치 — 세무사 상담을 권장합니다</span>
  </div>

  <%# ===== Input Row 1: Bid Price Slider + Sale Price ===== %>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">

    <%# Bid Price Slider %>
    <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-4">
      <label class="text-sm font-medium text-slate-600 dark:text-slate-400 block mb-2">예상 낙찰가</label>
      <div class="flex items-center gap-2 mb-2">
        <input type="text"
               data-profit-calculator-target="bidDisplay"
               data-action="input->profit-calculator#onBidInput blur->profit-calculator#onBidBlur"
               class="flex-1 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 text-sm text-right text-slate-900 dark:text-slate-100"
               inputmode="numeric" />
        <span class="text-sm text-slate-500 dark:text-slate-400">만원</span>
      </div>
      <input type="range"
             data-profit-calculator-target="bidSlider"
             data-action="input->profit-calculator#onBidSlider"
             min="<%= min_bid_manwon %>"
             max="<%= (appraisal_manwon * 1.2).to_i %>"
             value="<%= min_bid_manwon %>"
             step="100"
             class="w-full accent-blue-600" />
      <div class="flex justify-between text-xs text-slate-400 dark:text-slate-500 mt-1">
        <span>최저가</span>
        <span class="text-blue-600 dark:text-blue-400 font-medium" data-profit-calculator-target="bidPercent"></span>
        <span>감정가×1.2</span>
      </div>
    </div>

    <%# Sale Price Input %>
    <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-4">
      <label class="text-sm font-medium text-slate-600 dark:text-slate-400 block mb-2">예상 매도가</label>
      <div class="flex items-center gap-2 mb-2">
        <input type="text"
               data-profit-calculator-target="saleDisplay"
               data-action="input->profit-calculator#onSaleInput blur->profit-calculator#onSaleBlur"
               class="flex-1 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 text-sm text-right text-slate-900 dark:text-slate-100"
               inputmode="numeric"
               placeholder="금액을 입력하세요" />
        <span class="text-sm text-slate-500 dark:text-slate-400">만원</span>
      </div>
      <input type="hidden" data-profit-calculator-target="saleHidden" value="" />
      <div class="text-xs text-slate-400 dark:text-slate-500 mt-3 p-2 bg-slate-100 dark:bg-slate-700/50 rounded">
        네이버 부동산, KB시세 등을 참고하세요
      </div>
    </div>
  </div>

  <%# ===== Input Row 2: Ownership + Holding Period ===== %>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">

    <%# Ownership Type %>
    <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-4">
      <label class="text-sm font-medium text-slate-600 dark:text-slate-400 block mb-2">소유형태</label>
      <div class="flex flex-col gap-2">
        <% [["no_home", "무주택"], ["one_home", "1주택"], ["multi_home", "다주택"]].each_with_index do |(value, label), i| %>
          <label class="flex items-center gap-2 text-sm text-slate-900 dark:text-slate-100 cursor-pointer">
            <input type="radio" name="ownership" value="<%= value %>"
                   data-profit-calculator-target="ownership"
                   data-action="change->profit-calculator#calculate"
                   <%= "checked" if i == 0 %>
                   class="accent-blue-600" />
            <%= label %>
          </label>
        <% end %>
      </div>
      <p class="text-xs text-slate-400 dark:text-slate-500 mt-2">법인/매매업자는 별도의 세금 계산이 필요합니다</p>
    </div>

    <%# Holding Period %>
    <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-4">
      <label class="text-sm font-medium text-slate-600 dark:text-slate-400 block mb-2">예상 보유기간</label>
      <div class="flex flex-col gap-2">
        <% [["under_1y", "1년 미만"], ["1to2y", "1~2년"], ["over_2y", "2년 이상"]].each_with_index do |(value, label), i| %>
          <label class="flex items-center gap-2 text-sm text-slate-900 dark:text-slate-100 cursor-pointer">
            <input type="radio" name="holding_period" value="<%= value %>"
                   data-profit-calculator-target="holdingPeriod"
                   data-action="change->profit-calculator#calculate"
                   <%= "checked" if i == 2 %>
                   class="accent-blue-600" />
            <%= label %>
          </label>
        <% end %>
      </div>
    </div>
  </div>

  <%# ===== Result Area (populated by Stimulus) ===== %>
  <div data-profit-calculator-target="resultArea" class="hidden">

    <%# Summary Cards %>
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
      <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-3 text-center">
        <div class="text-xs text-slate-500 dark:text-slate-400 mb-1">총 투입비용</div>
        <div class="text-lg font-bold text-slate-900 dark:text-slate-100" data-profit-calculator-target="totalOutlay">—</div>
      </div>
      <div class="bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-lg p-3 text-center">
        <div class="text-xs text-slate-500 dark:text-slate-400 mb-1">총 비용</div>
        <div class="text-lg font-bold text-red-600 dark:text-red-400" data-profit-calculator-target="totalCosts">—</div>
      </div>
      <div class="rounded-lg p-3 text-center" data-profit-calculator-target="profitCard">
        <div class="text-xs mb-1" data-profit-calculator-target="profitLabel">순수익</div>
        <div class="text-xl font-extrabold" data-profit-calculator-target="netProfit">—</div>
      </div>
      <div class="rounded-lg p-3 text-center" data-profit-calculator-target="roiCard">
        <div class="text-xs mb-1" data-profit-calculator-target="roiLabel">수익률</div>
        <div class="text-xl font-extrabold" data-profit-calculator-target="roi">—</div>
      </div>
    </div>

    <%# Breakdown Table %>
    <div class="border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-slate-100 dark:bg-slate-800">
            <th class="px-4 py-2 text-left font-semibold text-slate-600 dark:text-slate-400 text-xs">항목</th>
            <th class="px-4 py-2 text-right font-semibold text-slate-600 dark:text-slate-400 text-xs">금액</th>
            <th class="px-4 py-2 text-right font-semibold text-slate-600 dark:text-slate-400 text-xs">비고</th>
          </tr>
        </thead>
        <tbody>
          <tr class="border-t border-slate-200 dark:border-slate-700">
            <td class="px-4 py-2 text-slate-900 dark:text-slate-100 font-medium">매도가</td>
            <td class="px-4 py-2 text-right text-slate-900 dark:text-slate-100 font-semibold" data-profit-calculator-target="rowSalePrice">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">사용자 입력</td>
          </tr>
          <tr class="border-t-2 border-slate-200 dark:border-slate-700">
            <td colspan="3" class="px-4 py-1 text-xs font-semibold text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-800/30">(-) 차감 항목</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">낙찰가</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowBidPrice">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">슬라이더 입력</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">인수금액</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowAssumed">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">권리분석 결과</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">취득세</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowAcqTax">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs" data-profit-calculator-target="rowAcqTaxNote">추정 (필요경비)</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">법무사비</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowScrivener">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">예산 설정값 (필요경비)</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">수선비</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowRepair">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">예산 설정값 (필요경비)</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">이사비(명도비)</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowMoving">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">예산 설정값 (경비 불산입)</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">미납 관리비</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowMaintenance">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs">예산 설정값 (경비 불산입)</td>
          </tr>
          <tr class="border-t border-slate-100 dark:border-slate-800">
            <td class="px-4 py-2 pl-7 text-slate-600 dark:text-slate-300">양도소득세</td>
            <td class="px-4 py-2 text-right text-red-600 dark:text-red-400" data-profit-calculator-target="rowCgt">—</td>
            <td class="px-4 py-2 text-right text-slate-400 dark:text-slate-500 text-xs" data-profit-calculator-target="rowCgtNote">추정 (필요경비만 공제)</td>
          </tr>
          <tr class="border-t-2 border-slate-900 dark:border-slate-100 bg-slate-50 dark:bg-slate-800/50">
            <td class="px-4 py-3 font-bold text-slate-900 dark:text-slate-100">순수익</td>
            <td class="px-4 py-3 text-right text-lg font-extrabold" data-profit-calculator-target="rowNetProfit">—</td>
            <td class="px-4 py-3 text-right font-semibold" data-profit-calculator-target="rowRoi">—</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <%# ===== Empty State (shown when sale price not entered) ===== %>
  <div data-profit-calculator-target="emptyState"
       class="text-center py-8 text-slate-400 dark:text-slate-500 text-sm">
    매도가를 입력하면 예상 순수익이 계산됩니다
  </div>

  <%# ===== Bottom Disclaimer ===== %>
  <div class="p-3 bg-amber-50 dark:bg-amber-900/10 border border-amber-200 dark:border-amber-800 rounded-lg text-xs text-amber-800 dark:text-amber-300">
    이 계산은 추정치이며 실제 세금과 다를 수 있습니다. 정확한 세금은 세무사에게 상담하세요. 양도소득세는 소유형태와 보유기간에 따른 실효세율로 간이 계산한 값입니다.
  </div>
</div>
```

- [ ] **Step 2: Verify existing tests still pass**

Run: `bin/rails test test/components/profit_calculator_component_test.rb`
Expected: 4 tests, 0 failures (data attributes and disclaimer text unchanged)

- [ ] **Step 3: Commit**

```bash
git add app/components/profit_calculator_component.html.erb
git commit -m "feat(f03): add full input UI and result table template

Adds slider + number input for bid price, sale price input,
ownership/holding period radios, summary cards, itemized breakdown
table, disclaimers. All result targets populated by Stimulus."
```

---

### Task 3: Stimulus controller — calculation logic

**Files:**
- Create: `app/javascript/controllers/profit_calculator_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/profit_calculator_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Real-time net profit calculator for pre-bid estimation.
// All amounts in 만원 (10,000 KRW). Tax rates are simplified
// effective rates — see spec section 5 for rationale.
export default class extends Controller {
  static targets = [
    "bidDisplay", "bidSlider", "bidPercent",
    "saleDisplay", "saleHidden",
    "ownership", "holdingPeriod",
    "resultArea", "emptyState",
    "totalOutlay", "totalCosts", "netProfit", "roi",
    "profitCard", "roiCard", "profitLabel", "roiLabel",
    "rowSalePrice", "rowBidPrice", "rowAssumed",
    "rowAcqTax", "rowAcqTaxNote", "rowScrivener", "rowRepair",
    "rowMoving", "rowMaintenance", "rowCgt", "rowCgtNote",
    "rowNetProfit", "rowRoi"
  ]

  static values = {
    minBid: Number,
    appraisal: Number,
    assumedAmount: Number,
    scrivenerFee: Number,
    repairCost: Number,
    movingCost: Number,
    maintenanceFee: Number
  }

  // Effective acquisition tax rates by ownership type
  static ACQ_TAX_RATES = {
    no_home: 0.011,
    one_home: 0.011,
    multi_home: 0.084
  }

  // Effective capital gains tax rates by ownership + holding period
  static CGT_RATES = {
    no_home:    { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.20 },
    one_home:   { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
    multi_home: { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 }
  }

  connect() {
    this.bidDisplayTarget.value = this.formatEok(this.minBidValue)
    this.bidSliderTarget.value = this.minBidValue
    this.updateBidPercent(this.minBidValue)
    this.calculate()
  }

  // --- Bid price: slider ↔ input sync ---

  onBidSlider() {
    const manwon = parseInt(this.bidSliderTarget.value, 10)
    this.bidDisplayTarget.value = this.formatEok(manwon)
    this.updateBidPercent(manwon)
    this.calculate()
  }

  onBidInput() {
    const manwon = this.parseKorean(this.bidDisplayTarget.value)
    if (manwon > 0) {
      this.bidSliderTarget.value = manwon
      this.updateBidPercent(manwon)
    }
    this.calculate()
  }

  onBidBlur() {
    const manwon = this.parseKorean(this.bidDisplayTarget.value)
    if (manwon > 0) {
      this.bidDisplayTarget.value = this.formatEok(manwon)
      this.bidSliderTarget.value = manwon
      this.updateBidPercent(manwon)
    }
    this.calculate()
  }

  // --- Sale price input ---

  onSaleInput() {
    const manwon = this.parseKorean(this.saleDisplayTarget.value)
    this.saleHiddenTarget.value = manwon > 0 ? manwon : ""
    this.calculate()
  }

  onSaleBlur() {
    const manwon = this.parseKorean(this.saleDisplayTarget.value)
    if (manwon > 0) {
      this.saleDisplayTarget.value = this.formatEok(manwon)
      this.saleHiddenTarget.value = manwon
    } else {
      this.saleDisplayTarget.value = ""
      this.saleHiddenTarget.value = ""
    }
    this.calculate()
  }

  // --- Core calculation ---

  calculate() {
    const bidPrice = this.parseKorean(this.bidDisplayTarget.value)
    const salePrice = parseInt(this.saleHiddenTarget.value, 10) || 0

    if (salePrice <= 0) {
      this.resultAreaTarget.classList.add("hidden")
      this.emptyStateTarget.classList.remove("hidden")
      return
    }

    this.resultAreaTarget.classList.remove("hidden")
    this.emptyStateTarget.classList.add("hidden")

    const ownership = this.selectedOwnership()
    const holdingPeriod = this.selectedHoldingPeriod()

    // Costs from budget settings
    const scrivenerFee = this.scrivenerFeeValue
    const repairCost = this.repairCostValue
    const movingCost = this.movingCostValue
    const maintenanceFee = this.maintenanceFeeValue
    const assumedAmount = this.assumedAmountValue

    // Investment
    const totalInvestment = bidPrice + assumedAmount

    // Tax calculations
    const acqTaxRate = this.constructor.ACQ_TAX_RATES[ownership] || 0.011
    const acquisitionTax = Math.round(bidPrice * acqTaxRate)

    // All costs (for net profit)
    const allCosts = acquisitionTax + scrivenerFee + repairCost + movingCost + maintenanceFee

    // Deductible costs only (for taxable gain)
    const deductibleCosts = acquisitionTax + scrivenerFee + repairCost

    // Capital gains tax
    const taxableGain = salePrice - totalInvestment - deductibleCosts
    const cgtRate = this.constructor.CGT_RATES[ownership]?.[holdingPeriod] || 0.20
    const capitalGainsTax = taxableGain > 0 ? Math.round(taxableGain * cgtRate) : 0

    // Final results
    const netProfit = salePrice - totalInvestment - allCosts - capitalGainsTax
    const totalOutlay = totalInvestment + allCosts
    const totalCostsAll = allCosts + capitalGainsTax
    const roiPercent = totalOutlay > 0 ? (netProfit / totalOutlay * 100) : 0

    // Update UI
    this.renderResults({
      salePrice, bidPrice, assumedAmount,
      acquisitionTax, acqTaxRate,
      scrivenerFee, repairCost, movingCost, maintenanceFee,
      capitalGainsTax, cgtRate,
      netProfit, totalOutlay, totalCostsAll, roiPercent
    })
  }

  // --- Rendering ---

  renderResults(r) {
    const positive = r.netProfit >= 0

    // Summary cards
    this.totalOutlayTarget.textContent = this.formatEok(r.totalOutlay)
    this.totalCostsTarget.textContent = this.formatEok(r.totalCostsAll)
    this.netProfitTarget.textContent = this.formatEok(Math.abs(r.netProfit))
    this.netProfitTarget.textContent = (positive ? "" : "-") + this.formatEok(Math.abs(r.netProfit))
    this.roiTarget.textContent = `${r.roiPercent.toFixed(1)}%`

    // Card colors
    const profitBg = positive
      ? "bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800"
      : "bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800"
    const profitText = positive
      ? "text-green-700 dark:text-green-400"
      : "text-red-700 dark:text-red-400"

    this.profitCardTarget.className = `rounded-lg p-3 text-center ${profitBg}`
    this.roiCardTarget.className = `rounded-lg p-3 text-center ${profitBg}`
    this.profitLabelTarget.className = `text-xs mb-1 ${positive ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`
    this.roiLabelTarget.className = `text-xs mb-1 ${positive ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`
    this.netProfitTarget.className = `text-xl font-extrabold ${profitText}`
    this.roiTarget.className = `text-xl font-extrabold ${profitText}`

    // Breakdown rows
    this.rowSalePriceTarget.textContent = this.formatEok(r.salePrice)
    this.rowBidPriceTarget.textContent = `-${this.formatEok(r.bidPrice)}`
    this.rowAssumedTarget.textContent = `-${this.formatEok(r.assumedAmount)}`
    this.rowAcqTaxTarget.textContent = `-${this.formatEok(r.acquisitionTax)}`
    this.rowAcqTaxNoteTarget.textContent = `추정 ~${(r.acqTaxRate * 100).toFixed(1)}% (필요경비)`
    this.rowScrivenerTarget.textContent = `-${this.formatEok(r.scrivenerFee)}`
    this.rowRepairTarget.textContent = `-${this.formatEok(r.repairCost)}`
    this.rowMovingTarget.textContent = `-${this.formatEok(r.movingCost)}`
    this.rowMaintenanceTarget.textContent = `-${this.formatEok(r.maintenanceFee)}`
    this.rowCgtTarget.textContent = `-${this.formatEok(r.capitalGainsTax)}`
    this.rowCgtNoteTarget.textContent = `추정 ~${(r.cgtRate * 100).toFixed(0)}% (필요경비만 공제)`

    // Bottom row
    this.rowNetProfitTarget.textContent = (positive ? "" : "-") + this.formatEok(Math.abs(r.netProfit))
    this.rowNetProfitTarget.className = `px-4 py-3 text-right text-lg font-extrabold ${profitText}`
    this.rowRoiTarget.textContent = `수익률 ${r.roiPercent.toFixed(1)}%`
    this.rowRoiTarget.className = `px-4 py-3 text-right font-semibold ${profitText}`
  }

  // --- Helpers ---

  selectedOwnership() {
    const checked = this.ownershipTargets.find(el => el.checked)
    return checked ? checked.value : "no_home"
  }

  selectedHoldingPeriod() {
    const checked = this.holdingPeriodTargets.find(el => el.checked)
    return checked ? checked.value : "over_2y"
  }

  updateBidPercent(manwon) {
    if (this.appraisalValue > 0) {
      const pct = ((manwon / this.appraisalValue) * 100).toFixed(0)
      this.bidPercentTarget.textContent = `감정가의 ${pct}%`
    }
  }

  // Parse Korean currency text to 만원 integer
  // Reuses logic from number_format_controller.js
  parseKorean(text) {
    if (!text || text.trim() === "") return 0
    let str = text.replace(/,/g, "").replace(/\s+/g, "").replace(/만원?/g, "")

    const eokMatch = str.match(/(\d+)억(.*)/)
    if (eokMatch) {
      const eok = parseInt(eokMatch[1], 10) * 10000
      let remainder = 0
      const rest = eokMatch[2]
      if (rest) {
        const cheonMatch = rest.match(/(\d+)천/)
        if (cheonMatch) {
          remainder = parseInt(cheonMatch[1], 10) * 1000
        } else {
          const digits = rest.replace(/[^0-9]/g, "")
          if (digits) remainder = parseInt(digits, 10)
        }
      }
      return eok + remainder
    }

    const cheonOnly = str.match(/(\d+)천/)
    if (cheonOnly) return parseInt(cheonOnly[1], 10) * 1000

    const digits = str.replace(/[^0-9]/g, "")
    return digits ? parseInt(digits, 10) : 0
  }

  // Format 만원 integer to Korean 억 display
  formatEok(manwon) {
    if (!manwon || manwon <= 0) return "0만원"
    const eok = Math.floor(manwon / 10000)
    const remainder = manwon % 10000
    if (eok >= 1 && remainder > 0) {
      return `${eok}억 ${remainder.toLocaleString("ko-KR")}만원`
    } else if (eok >= 1) {
      return `${eok}억`
    }
    return `${manwon.toLocaleString("ko-KR")}만원`
  }
}
```

- [ ] **Step 2: Verify the controller auto-registers**

Stimulus auto-discovers controllers via `app/javascript/controllers/index.js`. Run:

```bash
bin/rails stimulus:manifest:update
```

Check that `profit_calculator_controller` appears in `app/javascript/controllers/index.js`.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/profit_calculator_controller.js \
        app/javascript/controllers/index.js
git commit -m "feat(f03): add profit calculator Stimulus controller

Client-side real-time calculation with simplified effective tax rates.
Handles slider↔input sync, Korean currency parsing/formatting,
deductible vs non-deductible cost separation for capital gains tax."
```

---

### Task 4: Wire component into grade report page

**Files:**
- Modify: `app/views/inspections/grades/show.html.erb` (line 6, after BidOpinionComponent)

- [ ] **Step 1: Add render line to show.html.erb**

In `app/views/inspections/grades/show.html.erb`, after the BidOpinionComponent render (line 10), add:

```erb
    <%= render ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget_setting,
      report: @report
    ) %>
```

The file should look like:

```erb
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: "grade" } do %>
  <div class="space-y-6">
    <%= render PropertyInfoComponent.new(property: @property) %>
    <%= render ReportBudgetComponent.new(budget_setting: @budget_setting) %>
    <%= render GradeSummaryComponent.new(rating: @rating, fully_evaluated: @fully_evaluated, tabs_evaluated: @tabs_evaluated, tabs_total: @tabs_total) %>
    <%= render BidOpinionComponent.new(
      rating: @rating,
      report: @report,
      risk_results: @risk_results,
      budget_setting: @budget_setting,
      property: @property
    ) %>
    <%= render ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget_setting,
      report: @report
    ) %>
    <%= render TabSummaryTableComponent.new(results_by_tab: @results_by_tab, property: @property) %>
    ...
```

- [ ] **Step 2: Verify all component tests still pass**

Run: `bin/rails test test/components/`
Expected: All pass, no regressions

- [ ] **Step 3: Verify rubocop passes**

Run: `bin/rubocop app/components/profit_calculator_component.rb`
Expected: No offenses

- [ ] **Step 4: Commit**

```bash
git add app/views/inspections/grades/show.html.erb
git commit -m "feat(f03): wire ProfitCalculatorComponent into grade report

Renders after BidOpinionComponent in the grade report page.
Not included in PDF export (show.pdf.erb unchanged)."
```

---

### Task 5: Manual smoke test in browser

**Files:** None (verification only)

- [ ] **Step 1: Start the dev server**

Run: `bin/dev`

- [ ] **Step 2: Navigate to a property's grade page**

Open: `http://localhost:3000/properties/<id>/inspections/grade`

Use a property that has inspection results and a rights analysis report for full data.

- [ ] **Step 3: Verify input controls**

Check:
- Slider moves and updates the number input
- Typing in the number input updates the slider
- "감정가의 N%" indicator updates correctly
- Ownership radio buttons switch correctly
- Holding period radio buttons switch correctly

- [ ] **Step 4: Verify calculation results**

Enter a sale price (e.g., "3억 5000") and check:
- Summary cards show values (총 투입비용, 총 비용, 순수익, 수익률)
- Breakdown table shows all 9 rows with correct amounts
- Tax note columns show rate percentages
- Switching ownership/holding period changes tax amounts instantly

- [ ] **Step 5: Verify edge cases**

Check:
- Empty sale price → "매도가를 입력하면 예상 순수익이 계산됩니다"
- Sale price < bid price → negative profit shown in red
- Disclaimer badge and bottom disclaimer text visible
- "법인/매매업자는 별도의 세금 계산이 필요합니다" text visible

- [ ] **Step 6: Verify PDF is unaffected**

Visit: `http://localhost:3000/properties/<id>/inspections/grade.pdf`
Confirm: PDF does not contain the calculator

- [ ] **Step 7: Commit (no code changes — just a checkpoint)**

No commit needed — this is a verification step.

---

### Task 6: Run full CI pipeline

**Files:** None (verification only)

- [ ] **Step 1: Run the full CI script**

Run: `bin/ci`

This runs: setup, rubocop, brakeman, bundler-audit, importmap audit, and all tests.

- [ ] **Step 2: Fix any failures**

If any test fails, fix it and commit the fix separately.

- [ ] **Step 3: Final commit if needed**

If fixes were needed:

```bash
git add -A
git commit -m "fix(f03): resolve CI failures from profit calculator"
```
