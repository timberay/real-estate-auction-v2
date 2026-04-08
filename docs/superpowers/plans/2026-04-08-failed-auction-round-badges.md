# Failed Auction Round Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show per-round appraisal limit badges in the analysis screen header so users can see what appraisal price range they can target at each failed auction round.

**Architecture:** Add a helper method to compute per-round appraisal limits, then loop over rounds in the shared inspection layout to render emerald-colored badges. Pure server-side rendering, no JS changes.

**Tech Stack:** Rails helpers, ERB, Tailwind CSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-08-failed-auction-round-badges-design.md`

---

### Task 1: Add `appraisal_limits_by_round` helper method

**Files:**
- Modify: `app/helpers/application_helper.rb`
- Test: `test/helpers/application_helper_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/helpers/application_helper_test.rb`:

```ruby
# --- appraisal_limits_by_round ---

test "returns empty array when rounds is 0" do
  assert_equal [], appraisal_limits_by_round(10000, 0)
end

test "returns 1 entry for 1 round" do
  # 10000 / 0.8 = 12500
  assert_equal [ { round: 1, limit: 12500 } ], appraisal_limits_by_round(10000, 1)
end

test "returns entries for multiple rounds" do
  # round 1: 10000 / 0.8 = 12500
  # round 2: 10000 / 0.64 = 15625
  result = appraisal_limits_by_round(10000, 2)
  assert_equal 2, result.length
  assert_equal({ round: 1, limit: 12500 }, result[0])
  assert_equal({ round: 2, limit: 15625 }, result[1])
end

test "floors fractional results" do
  # 9620 / 0.8 = 12025.0
  # 9620 / 0.64 = 15031.25 → 15031
  result = appraisal_limits_by_round(9620, 2)
  assert_equal 12025, result[0][:limit]
  assert_equal 15031, result[1][:limit]
end

test "returns empty array when max_bid is nil" do
  assert_equal [], appraisal_limits_by_round(nil, 2)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/helpers/application_helper_test.rb -v`
Expected: 5 failures — `NoMethodError: undefined method 'appraisal_limits_by_round'`

- [ ] **Step 3: Implement the helper**

Add to `app/helpers/application_helper.rb`, inside the module:

```ruby
# Returns an array of { round:, limit: } hashes for each failed auction round.
# limit = floor(max_bid_amount / 0.8^round)
def appraisal_limits_by_round(max_bid_amount, failed_auction_rounds)
  return [] if max_bid_amount.nil? || failed_auction_rounds < 1

  (1..failed_auction_rounds).map do |round|
    reduction = BigDecimal("0.8")**round
    { round: round, limit: (max_bid_amount / reduction).floor }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/helpers/application_helper_test.rb -v`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/helpers/application_helper.rb test/helpers/application_helper_test.rb
git commit -m "feat(helper): add appraisal_limits_by_round for per-round limit calculation"
```

---

### Task 2: Add round badges to inspection layout

**Files:**
- Modify: `app/views/inspections/_layout.html.erb:18-25`

- [ ] **Step 1: Add round badge loop after existing 최대입찰가 badge**

Replace lines 18-25 of `app/views/inspections/_layout.html.erb` (the budget badge block) with:

```erb
<% budget = current_user.budget_setting %>
<% if budget&.max_bid_amount.present? %>
  <%= link_to settings_budget_path,
      class: "inline-flex items-center gap-1.5 rounded-md bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 px-3 h-8 hover:bg-blue-100 dark:hover:bg-blue-800/30 transition-colors duration-150" do %>
    <span class="text-sm text-slate-500 dark:text-slate-400">최대입찰가</span>
    <span class="text-sm font-bold tabular-nums text-blue-700 dark:text-blue-300"><%= format_price_in_eok(budget.max_bid_amount) %></span>
  <% end %>
  <% appraisal_limits_by_round(budget.max_bid_amount, budget.failed_auction_rounds).each do |entry| %>
    <%= link_to settings_budget_path,
        class: "inline-flex items-center gap-1.5 rounded-md bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800 px-3 h-8 hover:bg-emerald-100 dark:hover:bg-emerald-800/30 transition-colors duration-150" do %>
      <span class="text-sm text-emerald-600 dark:text-emerald-400"><%= entry[:round] %>회</span>
      <span class="text-sm font-bold tabular-nums text-emerald-700 dark:text-emerald-300"><%= format_price_in_eok(entry[:limit]) %></span>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 2: Verify in browser**

Run: `bin/dev`
Navigate to any property's inspection page. Confirm:
- When `failed_auction_rounds == 0`: only 최대입찰가 badge shown (no change)
- When `failed_auction_rounds >= 1`: green round badges appear after the blue badge
- Badges wrap correctly on narrow screens
- All badges link to budget settings page

- [ ] **Step 3: Commit**

```bash
git add app/views/inspections/_layout.html.erb
git commit -m "feat(ui): add failed auction round badges to analysis screen header"
```
