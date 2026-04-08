# Auction Round Price Breakdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a dynamic round-by-round price breakdown table below the max bid preview in onboarding step 3, so users see how appraisal price reduces through each failed auction round.

**Architecture:** Add a Stimulus target container in the ERB view, then extend the existing `loan-slider` controller with a `renderRoundBreakdown()` method that generates the table HTML on every slider change. All calculation is client-side using the same formula already in `updateAll()`.

**Tech Stack:** Stimulus (pure JS), ERB, TailwindCSS

---

### Task 1: Add round breakdown container to step3 ERB

**Files:**
- Modify: `app/views/onboardings/step3.html.erb:59-62`

- [ ] **Step 1: Add the target div below the max bid preview card**

Insert a new `div` immediately after the existing max bid preview card (line 62), inside the same `loan-slider` controller scope. This div will be populated by JavaScript.

In `app/views/onboardings/step3.html.erb`, after the closing `</div>` of the max bid preview card (the `mb-6 p-4 bg-blue-50` div at line 62), add:

```erb
        <div data-loan-slider-target="roundBreakdown" class="mb-6"></div>
```

- [ ] **Step 2: Verify the page still renders**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb -v`
Expected: All existing tests PASS (no breakage from adding an empty div).

- [ ] **Step 3: Commit**

```bash
git add app/views/onboardings/step3.html.erb
git commit -m "feat(ui): add round breakdown target container in step3 view"
```

---

### Task 2: Add `roundBreakdown` target to Stimulus controller

**Files:**
- Modify: `app/javascript/controllers/loan_slider_controller.js`

- [ ] **Step 1: Register the new target**

In `app/javascript/controllers/loan_slider_controller.js`, add `"roundBreakdown"` to the `static targets` array:

```javascript
  static targets = [
    "slider", "ratioDisplay", "maxBidPreview", "hiddenRatio",
    "roundsSlider", "roundsDisplay", "limitPreview",
    "roundBreakdown"
  ]
```

- [ ] **Step 2: Add the `renderRoundBreakdown()` method**

Add this method to the controller class, after the `updateAll()` method:

```javascript
  renderRoundBreakdown(maxBid, rounds) {
    if (!this.hasRoundBreakdownTarget) return

    if (maxBid <= 0) {
      this.roundBreakdownTarget.innerHTML = ""
      return
    }

    const factor = Math.pow(0.8, rounds)
    const appraisalPrice = rounds === 0 ? maxBid : Math.floor(maxBid / factor)

    const headerText = rounds === 0 ? "신건 기준" : `유찰 ${rounds}회차 기준`

    let rowsHtml = ""

    // 감정가 row — highlighted when round 0
    const appraisalHighlight = rounds === 0
    rowsHtml += this.#breakdownRow("감정가", appraisalPrice, appraisalHighlight)

    // Each round's 최저입찰가
    for (let r = 1; r <= rounds; r++) {
      const minBid = Math.floor(appraisalPrice * Math.pow(0.8, r))
      const isLast = r === rounds
      rowsHtml += this.#breakdownRow(`${r}회 유찰 → 최저가`, minBid, isLast)
    }

    this.roundBreakdownTarget.innerHTML = `
      <div class="p-4 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg">
        <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">${headerText}</p>
        <div class="space-y-1.5">${rowsHtml}</div>
      </div>
    `
  }

  #breakdownRow(label, amount, highlighted) {
    const valueClass = highlighted
      ? "text-sm font-bold tabular-nums text-blue-600 dark:text-blue-400"
      : "text-sm tabular-nums text-slate-600 dark:text-slate-300"
    const labelClass = highlighted
      ? "text-sm text-blue-600 dark:text-blue-400 font-medium"
      : "text-sm text-slate-500 dark:text-slate-400"

    return `
      <div class="flex justify-between items-center">
        <span class="${labelClass}">${label}</span>
        <span class="${valueClass}">${amount.toLocaleString("ko-KR")}만원</span>
      </div>
    `
  }
```

- [ ] **Step 3: Call `renderRoundBreakdown()` from `updateAll()`**

In the `updateAll()` method, add the call at the end. Replace the section starting from `// Failed rounds calculation`:

```javascript
    // Failed rounds calculation
    if (this.hasRoundsSliderTarget) {
      const rounds = parseInt(this.roundsSliderTarget.value, 10)
      this.roundsDisplayTarget.textContent = `${rounds}회차`

      if (rounds === 0) {
        this.limitPreviewTarget.textContent = `${maxBid.toLocaleString("ko-KR")}만원`
      } else {
        const factor = Math.pow(0.8, rounds)
        const limit = Math.floor(maxBid / factor)
        this.limitPreviewTarget.textContent = `${limit.toLocaleString("ko-KR")}만원`
      }

      this.renderRoundBreakdown(maxBid, rounds)
    }
```

The only change is adding `this.renderRoundBreakdown(maxBid, rounds)` as the last line inside the `if` block.

- [ ] **Step 4: Verify by running the dev server**

Run: `bin/dev`

1. Navigate to onboarding step 3
2. Move the 유찰 회차 slider to each position (0, 1, 2, 3)
3. Verify the breakdown table appears and updates dynamically
4. Verify round 0 shows "신건 기준" with 감정가 highlighted
5. Verify round 3 shows 감정가 + 3 rows, last row highlighted in blue
6. Change the LTV slider — verify breakdown recalculates

- [ ] **Step 5: Handle the "계산 불가" edge case**

In the `updateAll()` method, inside the early return for `netCash <= 0 || ratio >= 1`, clear the breakdown too. Update the early return block:

```javascript
    if (netCash <= 0 || ratio >= 1) {
      this.maxBidPreviewTarget.textContent = "계산 불가"
      if (this.hasLimitPreviewTarget) {
        this.limitPreviewTarget.textContent = "계산 불가"
      }
      this.renderRoundBreakdown(0, 0)
      return
    }
```

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/loan_slider_controller.js
git commit -m "feat(ui): add dynamic round-by-round price breakdown table

Show appraisal price and per-round minimum bid prices below
the max bid preview. Updates on every slider change."
```

---

### Task 3: System test for round breakdown display

**Files:**
- Create: `test/system/onboarding_round_breakdown_test.rb`

- [ ] **Step 1: Write system test**

```ruby
require "application_system_test_case"

class OnboardingRoundBreakdownTest < ApplicationSystemTestCase
  setup do
    @user = users(:default)
    @setting = @user.budget_setting
    @setting.update!(
      available_cash: 50_000,
      repair_cost: 500,
      acquisition_tax: 300,
      scrivener_fee: 100,
      moving_cost: 50,
      maintenance_fee: 50,
      property_type: property_types(:apartment)
    )
    sign_in_as(@user) if respond_to?(:sign_in_as)
  end

  test "round breakdown table updates when failed auction rounds slider changes" do
    visit step3_onboarding_path

    # Round 0 (신건) — should show 감정가 only
    fill_in_slider("budget_setting[failed_auction_rounds]", with: 0)
    within("[data-loan-slider-target='roundBreakdown']") do
      assert_text "신건 기준"
      assert_text "감정가"
      assert_no_text "유찰 → 최저가"
    end

    # Round 2 — should show 감정가 + 2 round rows
    fill_in_slider("budget_setting[failed_auction_rounds]", with: 2)
    within("[data-loan-slider-target='roundBreakdown']") do
      assert_text "유찰 2회차 기준"
      assert_text "감정가"
      assert_text "1회 유찰 → 최저가"
      assert_text "2회 유찰 → 최저가"
      assert_no_text "3회 유찰 → 최저가"
    end
  end

  private

  def fill_in_slider(name, with:)
    slider = find("input[name='#{name}']")
    slider.set(with)
    slider.trigger("input")
  end
end
```

- [ ] **Step 2: Run the system test**

Run: `bin/rails test test/system/onboarding_round_breakdown_test.rb -v`
Expected: PASS (Note: if fixtures or auth helpers don't match this project's setup, adapt accordingly — check `test/test_helper.rb` and `test/fixtures/` for the correct names.)

- [ ] **Step 3: Commit**

```bash
git add test/system/onboarding_round_breakdown_test.rb
git commit -m "test: add system test for round breakdown table display"
```
