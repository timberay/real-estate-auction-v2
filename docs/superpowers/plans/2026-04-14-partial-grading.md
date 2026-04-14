# Partial Grading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to save and receive safety evaluations based on partially-completed checklist items, instead of requiring all items to be answered first.

**Architecture:** Modify `InspectionRatingService` to evaluate only answered items (treating unanswered as "not yet reviewed" rather than blocking). Update `TabsController#update` to trigger evaluation on save and pass results via flash. Add unanswered count badges to tab navigation and a post-save result banner.

**Tech Stack:** Rails 8.1, Minitest, Stimulus (JS), ViewComponent, TailwindCSS

---

### Task 1: Update InspectionRatingService — partial evaluation for `call`

**Files:**
- Modify: `app/services/inspection_rating_service.rb:11-31`
- Modify: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Update the existing "incomplete" test to match new semantics**

The test `returns incomplete when unanswered items exist` currently expects `:incomplete` when any item has `has_risk: nil`. Under partial grading, this should return `:incomplete` only when ALL items are unanswered (zero answered). The existing test creates one unanswered item with no answered items, so it already matches the new behavior. No change needed to this test.

Write a new test for the key new scenario — partial answers should grade based on answered items only:

```ruby
# test/services/inspection_rating_service_test.rb
# Add after the existing "returns incomplete" test:

test "rates safe when some items answered safe and others unanswered" do
  item2 = inspection_items(:rights_002)
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
  rating = InspectionRatingService.call(property: @property, user: @user)
  assert_equal :safe, rating
end

test "rates danger when answered item has unresolvable risk despite unanswered items" do
  item2 = inspection_items(:rights_002)
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
  InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
  rating = InspectionRatingService.call(property: @property, user: @user)
  assert_equal :danger, rating
end
```

- [ ] **Step 2: Run tests to verify the new tests fail**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: 2 new tests FAIL (the "rates safe when some items answered" test will return `:incomplete` instead of `:safe`)

- [ ] **Step 3: Implement partial evaluation in `call` method**

Replace the `call` method body in `app/services/inspection_rating_service.rb`:

```ruby
def call
  results = @property.inspection_results.where(user: @user)
  answered = results.where.not(has_risk: nil)

  if answered.empty?
    return :incomplete
  end

  rating = if answered.exists?(has_risk: true, resolvable: false)
    :danger
  elsif answered.exists?(has_risk: true)
    :caution
  else
    :safe
  end

  user_property = UserProperty.find_by!(user: @user, property: @property)
  user_property.update!(safety_rating: rating, analyzed_at: Time.current)
  rating
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: ALL tests PASS (including old tests — the existing "incomplete" test still passes because it creates zero answered items)

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: evaluate grades based on answered items only in call method"
```

---

### Task 2: Update InspectionRatingService — partial evaluation for `tab_rating`

**Files:**
- Modify: `app/services/inspection_rating_service.rb:33-51`
- Modify: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Update the existing tab_rating "incomplete" test and add partial test**

The existing test `tab_rating returns incomplete when unanswered items exist in tab` creates one unanswered item — this still returns `:incomplete` under new logic (zero answered in that tab). Add a test for the partial case:

```ruby
# test/services/inspection_rating_service_test.rb
# Add after "tab_rating returns incomplete" test:

test "tab_rating rates safe when some tab items answered and others unanswered" do
  item2 = inspection_items(:rights_002)
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_equal :safe, service.tab_rating("rights_analysis")
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inspection_rating_service_test.rb -n "test_tab_rating_rates_safe_when_some_tab_items_answered_and_others_unanswered"`
Expected: FAIL — returns `:incomplete` instead of `:safe`

- [ ] **Step 3: Implement partial evaluation in `tab_rating`**

Replace the `tab_rating` method in `app/services/inspection_rating_service.rb`:

```ruby
def tab_rating(tab_key)
  tab_int = InspectionItem.tabs[tab_key]
  results = @property.inspection_results
    .joins(:inspection_item)
    .where(inspection_items: { tab: tab_int }, user: @user)

  return nil if results.empty?

  answered = results.where.not(has_risk: nil)
  return :incomplete if answered.empty?

  if answered.exists?(has_risk: true, resolvable: false)
    :danger
  elsif answered.exists?(has_risk: true)
    :caution
  else
    :safe
  end
end
```

- [ ] **Step 4: Run all service tests**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: evaluate tab_rating based on answered items only"
```

---

### Task 3: Add `fully_evaluated?` helper to InspectionRatingService

The `GradeSummaryComponent` needs to know whether grading is based on complete or partial data. Add a helper method.

**Files:**
- Modify: `app/services/inspection_rating_service.rb`
- Modify: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Write tests for `fully_evaluated?`**

```ruby
# test/services/inspection_rating_service_test.rb

test "fully_evaluated? returns false when no results exist" do
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_not service.fully_evaluated?
end

test "fully_evaluated? returns false when unanswered items exist" do
  item2 = inspection_items(:rights_002)
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_not service.fully_evaluated?
end

test "fully_evaluated? returns true when all items answered" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert service.fully_evaluated?
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inspection_rating_service_test.rb -n "/fully_evaluated/"`
Expected: FAIL — `NoMethodError: undefined method 'fully_evaluated?'`

- [ ] **Step 3: Implement `fully_evaluated?`**

Add to `app/services/inspection_rating_service.rb`, after the `tab_rating` method:

```ruby
def fully_evaluated?
  results = @property.inspection_results.where(user: @user)
  results.any? && results.where(has_risk: nil).none?
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: add fully_evaluated? helper to InspectionRatingService"
```

---

### Task 4: Add `tabs_evaluated_count` helper to InspectionRatingService

The `GradeSummaryComponent` needs to show "5개 중 3개 탭 분석 완료" progress info.

**Files:**
- Modify: `app/services/inspection_rating_service.rb`
- Modify: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Write tests**

```ruby
# test/services/inspection_rating_service_test.rb

test "tabs_evaluated_count returns counts of evaluated and total tabs" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  service = InspectionRatingService.new(property: @property, user: @user)
  evaluated, total = service.tabs_evaluated_count
  assert_equal 1, evaluated
  assert_equal 5, total
end

test "tabs_evaluated_count counts tab as evaluated when at least one item answered" do
  item_prop = inspection_items(:property_001)
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  InspectionResult.create!(property: @property, inspection_item: item_prop, user: @user, source_type: "auto", has_risk: true, resolvable: true)
  service = InspectionRatingService.new(property: @property, user: @user)
  evaluated, total = service.tabs_evaluated_count
  assert_equal 2, evaluated
  assert_equal 5, total
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inspection_rating_service_test.rb -n "/tabs_evaluated_count/"`
Expected: FAIL — `NoMethodError`

- [ ] **Step 3: Implement `tabs_evaluated_count`**

Add to `app/services/inspection_rating_service.rb`, after `fully_evaluated?`:

```ruby
ANALYSIS_TABS = %w[rights_analysis property_analysis profit_analysis field_check bidding].freeze

def tabs_evaluated_count
  evaluated = ANALYSIS_TABS.count do |tab_key|
    rating = tab_rating(tab_key)
    rating && rating != :incomplete
  end
  [evaluated, ANALYSIS_TABS.size]
end
```

Note: `tab_rating` returns `nil` when no results exist for a tab, and `:incomplete` when results exist but none are answered. A tab counts as "evaluated" when `tab_rating` returns `:safe`, `:caution`, or `:danger`.

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: add tabs_evaluated_count helper for progress display"
```

---

### Task 5: Remove save button validation in unified_form_controller.js

**Files:**
- Modify: `app/javascript/controllers/unified_form_controller.js`

- [ ] **Step 1: Simplify the `validate` method**

Replace the entire `validate()` method in `app/javascript/controllers/unified_form_controller.js`. Keep the progress counter logic, remove the button disable/enable logic:

```javascript
validate() {
  const manualCards = this.element.querySelectorAll(
    "[data-inspection-item-auto-value='false']"
  )
  const total = this.totalValue
  let completedManual = 0

  manualCards.forEach(card => {
    const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']:not(:disabled)")
    const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)

    if (hasRiskChecked) {
      completedManual++
    }
  })

  const autoCount = total - manualCards.length
  const completed = autoCount + completedManual

  if (this.hasProgressTarget) {
    this.progressTarget.textContent = `${completed}/${total}`
  }
}
```

- [ ] **Step 2: Update `tabs/edit.html.erb` to remove disabled state from submit button**

In `app/views/inspections/tabs/edit.html.erb`, replace the submit button section. Remove the `has_incomplete` variable, `disabled` attribute, and conditional CSS classes:

Replace:
```erb
<% has_incomplete = @results.any? { |r| !r.auto? && r.has_risk.nil? } %>
<%= f.submit "저장하기", disabled: has_incomplete,
    class: "h-10 px-4 rounded-md bg-blue-600 dark:bg-blue-500 text-base font-semibold text-white transition-colors focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900 #{has_incomplete ? 'opacity-50 cursor-not-allowed' : 'hover:bg-blue-700 dark:hover:bg-blue-400'}",
    data: { unified_form_target: "submitButton" } %>
```

With:
```erb
<%= f.submit "저장하기",
    class: "h-10 px-4 rounded-md bg-blue-600 dark:bg-blue-500 text-base font-semibold text-white transition-colors hover:bg-blue-700 dark:hover:bg-blue-400 focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900",
    data: { unified_form_target: "submitButton" } %>
```

- [ ] **Step 3: Verify the dev server renders correctly**

Run: `bin/dev` (if not already running)
Navigate to any tab edit page and confirm:
- Save button is always enabled (blue, clickable)
- Progress counter still updates as you answer items

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/unified_form_controller.js app/views/inspections/tabs/edit.html.erb
git commit -m "feat: always enable save button regardless of completion"
```

---

### Task 6: Add post-save rating calculation to TabsController#update

**Files:**
- Modify: `app/controllers/inspections/tabs_controller.rb:19-47`
- Modify: `test/controllers/inspections/tabs_controller_test.rb`

- [ ] **Step 1: Write test for flash[:tab_rating] after save**

```ruby
# test/controllers/inspections/tabs_controller_test.rb
# Add after existing tests:

test "update sets flash with tab rating and unanswered count" do
  result = @property.inspection_results
    .where(user: users(:guest))
    .joins(:inspection_item)
    .where(inspection_items: { tab: InspectionItem.tabs["rights_analysis"] })
    .first

  patch property_inspections_tab_url(@property, tab_key: "rights_analysis"), params: {
    resolutions: {
      result.id => {
        has_risk: "false"
      }
    }
  }

  assert_response :redirect
  tab_rating_flash = flash[:tab_rating]
  assert_not_nil tab_rating_flash
  assert_includes %w[safe caution danger incomplete], tab_rating_flash["rating"]
  assert_equal "권리분석", tab_rating_flash["label"]
  assert tab_rating_flash.key?("unanswered_count")
end

test "update with no resolutions still sets flash" do
  patch property_inspections_tab_url(@property, tab_key: "rights_analysis"), params: {}

  assert_response :redirect
  tab_rating_flash = flash[:tab_rating]
  assert_not_nil tab_rating_flash
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/inspections/tabs_controller_test.rb -n "/flash/"`
Expected: FAIL — `flash[:tab_rating]` is `nil`

- [ ] **Step 3: Add post-save rating calculation to `update` action**

In `app/controllers/inspections/tabs_controller.rb`, replace the `redirect_to` line at the end of the `update` method with the rating calculation + flash + redirect:

Replace:
```ruby
redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key, anchor: "top")
```

With:
```ruby
rating_service = InspectionRatingService.new(property: @property, user: current_user)
rating_service.call

tab_rating_value = rating_service.tab_rating(@tab_key)

tab_results = @property.inspection_results
  .joins(:inspection_item)
  .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] }, user: current_user)
unanswered_count = tab_results.where(has_risk: nil).count

tab_label = TabSummaryTableComponent::TAB_LABELS[@tab_key] || @tab_key

flash[:tab_rating] = {
  "rating" => tab_rating_value.to_s,
  "label" => tab_label,
  "unanswered_count" => unanswered_count
}

redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key, anchor: "top")
```

- [ ] **Step 4: Run all controller tests**

Run: `bin/rails test test/controllers/inspections/tabs_controller_test.rb`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/inspections/tabs_controller.rb test/controllers/inspections/tabs_controller_test.rb
git commit -m "feat: calculate and flash tab rating on save"
```

---

### Task 7: Add post-save result banner to tab edit page

**Files:**
- Modify: `app/views/inspections/tabs/edit.html.erb`

- [ ] **Step 1: Add the banner partial rendering**

In `app/views/inspections/tabs/edit.html.erb`, add the banner after `<div id="top"></div>` and before the `form_with`:

```erb
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: @tab_key } do %>
  <div id="top"></div>
  <% if (tab_rating = flash[:tab_rating]) %>
    <% rating_key = tab_rating["rating"] %>
    <% badge_config = {
      "safe" => { label: "안전", bg: "bg-green-50 dark:bg-green-900/20", border: "border-green-300 dark:border-green-700", text: "text-green-800 dark:text-green-300", badge_bg: "bg-green-600 dark:bg-green-500" },
      "caution" => { label: "주의", bg: "bg-yellow-50 dark:bg-yellow-900/20", border: "border-yellow-300 dark:border-yellow-700", text: "text-yellow-800 dark:text-yellow-300", badge_bg: "bg-yellow-600 dark:bg-yellow-500" },
      "danger" => { label: "경고", bg: "bg-red-50 dark:bg-red-900/20", border: "border-red-300 dark:border-red-700", text: "text-red-800 dark:text-red-300", badge_bg: "bg-red-600 dark:bg-red-500" },
      "incomplete" => { label: "미평가", bg: "bg-slate-50 dark:bg-slate-800/50", border: "border-slate-300 dark:border-slate-600", text: "text-slate-700 dark:text-slate-300", badge_bg: "bg-slate-500 dark:bg-slate-400" }
    } %>
    <% config = badge_config[rating_key] || badge_config["incomplete"] %>
    <div class="mb-4 rounded-lg border <%= config[:border] %> <%= config[:bg] %> px-4 py-3 flex items-center gap-3">
      <span class="<%= config[:badge_bg] %> text-white text-sm font-bold px-2.5 py-1 rounded-md"><%= config[:label] %></span>
      <span class="<%= config[:text] %> text-sm font-medium">
        <strong><%= tab_rating["label"] %></strong> 평가 완료
        <% if tab_rating["unanswered_count"].to_i > 0 %>
          — <span class="font-semibold">미응답 <%= tab_rating["unanswered_count"] %>개</span>가 남아있습니다
        <% end %>
      </span>
    </div>
  <% end %>
  <%= form_with url: property_inspections_tab_path(@property, tab_key: @tab_key), method: :patch,
```

- [ ] **Step 2: Verify in browser**

Run: `bin/dev` (if not already running)
1. Navigate to a tab edit page
2. Answer some items and click "저장하기"
3. Confirm the banner appears at the top with the correct rating and unanswered count
4. Navigate to another tab — confirm the banner is gone

- [ ] **Step 3: Commit**

```bash
git add app/views/inspections/tabs/edit.html.erb
git commit -m "feat: show post-save rating banner on tab edit page"
```

---

### Task 8: Optimize InspectionTabsComponent with batch query

Before adding the unanswered badge, optimize the component to avoid N+1 queries by batch-loading all tab statistics.

**Files:**
- Modify: `app/components/inspection_tabs_component.rb`

- [ ] **Step 1: Refactor to batch-load tab statistics**

Replace `app/components/inspection_tabs_component.rb` with:

```ruby
class InspectionTabsComponent < ViewComponent::Base
  TAB_CONFIG = [
    { key: "rights_analysis",   label: "권리분석" },
    { key: "property_analysis", label: "물건분석" },
    { key: "profit_analysis",   label: "수익분석" },
    { key: "field_check",       label: "현장확인" },
    { key: "bidding",           label: "입찰&낙찰" },
    { key: "grade",             label: "종합 판정" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
    @tab_stats = load_tab_stats
  end

  private

  def tabs
    rating_service = InspectionRatingService.new(property: @property, user: @user)
    TAB_CONFIG.map do |tab|
      stats = @tab_stats[tab[:key]] || { checked: 0, total: 0 }
      tab.merge(
        active: tab[:key] == @active_tab,
        url: tab_url(tab[:key]),
        checked: stats[:checked],
        total: stats[:total],
        rating: tab[:key] == "grade" ? nil : rating_service.tab_rating(tab[:key])
      )
    end
  end

  def load_tab_stats
    results = @property.inspection_results
      .joins(:inspection_item)
      .where(user: @user)
      .group("inspection_items.tab")
      .select(
        "inspection_items.tab",
        "COUNT(*) AS total_count",
        "COUNT(CASE WHEN inspection_results.has_risk IS NOT NULL THEN 1 END) AS checked_count"
      )

    tab_int_to_key = InspectionItem.tabs.invert
    results.each_with_object({}) do |row, hash|
      key = tab_int_to_key[row.tab.to_i]
      next unless key
      hash[key] = { checked: row.checked_count.to_i, total: row.total_count.to_i }
    end
  end

  def tab_url(key)
    if key == "grade"
      helpers.property_inspections_grade_path(@property)
    else
      helpers.edit_property_inspections_tab_path(@property, tab_key: key)
    end
  end

  RATING_BADGE = {
    safe: { label: "안전", classes: "bg-green-200 text-green-800 dark:bg-green-900/40 dark:text-green-300" },
    caution: { label: "주의", classes: "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300" },
    danger: { label: "경고", classes: "bg-red-200 text-red-800 dark:bg-red-900/40 dark:text-red-300" }
  }.freeze

  def rating_badge(rating)
    RATING_BADGE[rating]
  end
end
```

- [ ] **Step 2: Verify in browser**

Navigate to any inspection tab page. Confirm:
- Tab navigation renders correctly with checked/total counts
- Rating badges still appear on evaluated tabs
- No visual regressions

- [ ] **Step 3: Commit**

```bash
git add app/components/inspection_tabs_component.rb
git commit -m "refactor: batch-load tab statistics to avoid N+1 queries"
```

---

### Task 9: Add unanswered badge to tab navigation

**Files:**
- Modify: `app/components/inspection_tabs_component.html.erb`

- [ ] **Step 1: Add the amber unanswered badge**

In `app/components/inspection_tabs_component.html.erb`, add the unanswered count badge after the existing `checked/total` counter. The badge shows only when the tab has been evaluated (rating is not nil and not `:incomplete`) and has unanswered items.

Replace the non-grade tab link block (the `else` branch) in the template:

```erb
<%= link_to tab[:url],
    class: "px-3 py-2 rounded-md transition-colors whitespace-nowrap #{tab[:active] ? 'bg-blue-600 text-white font-semibold dark:bg-blue-500' : 'bg-slate-100 text-slate-600 hover:bg-slate-200 hover:text-slate-900 dark:bg-slate-800 dark:text-slate-400 dark:hover:bg-slate-700 dark:hover:text-slate-200'}" do %>
  <% if (badge = rating_badge(tab[:rating])) %>
    <span class="<%= badge[:classes] %> text-sm font-semibold px-1.5 py-0.5 rounded"><%= badge[:label] %></span>
  <% end %>
  <span><%= tab[:label] %></span>
  <% if tab[:total] > 0 %>
    <span class="ml-1 text-sm <%= tab[:active] ? 'text-blue-200' : 'text-slate-400 dark:text-slate-500' %>"><%= tab[:checked] %>/<%= tab[:total] %></span>
    <% unanswered = tab[:total] - tab[:checked] %>
    <% if unanswered > 0 && tab[:rating] && tab[:rating] != :incomplete %>
      <span class="ml-1 bg-amber-400 text-amber-900 dark:bg-amber-500 dark:text-amber-950 text-xs font-bold px-1.5 py-0.5 rounded-full"><%= unanswered %></span>
    <% end %>
  <% end %>
<% end %>
```

- [ ] **Step 2: Verify in browser**

1. Navigate to a tab, answer some (not all) items, save
2. Confirm the amber badge shows the unanswered count on the saved tab
3. Navigate to a fully-answered tab — confirm no amber badge
4. Navigate to a never-saved tab — confirm no amber badge (just "0/N")

- [ ] **Step 3: Commit**

```bash
git add app/components/inspection_tabs_component.html.erb
git commit -m "feat: show amber unanswered count badge on evaluated tabs"
```

---

### Task 10: Update GradeSummaryComponent for partial evaluation display

**Files:**
- Modify: `app/components/grade_summary_component.rb`
- Modify: `app/components/grade_summary_component.html.erb`
- Modify: `app/views/inspections/grades/show.html.erb`
- Modify: `app/controllers/inspections/grades_controller.rb`

- [ ] **Step 1: Update RATING_CONFIG and add partial evaluation support**

Replace `app/components/grade_summary_component.rb`:

```ruby
class GradeSummaryComponent < ViewComponent::Base
  RATING_CONFIG = {
    safe: { color: "text-green-700 dark:text-green-400", bg: "bg-green-100 dark:bg-green-900/20 border-green-400 dark:border-green-700", label: "안전", description: "위험 항목이 없습니다" },
    caution: { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-100 dark:bg-yellow-900/20 border-yellow-400 dark:border-yellow-700", label: "주의", description: "위험 항목이 있으나 모두 해결 가능합니다" },
    danger: { color: "text-red-700 dark:text-red-400", bg: "bg-red-100 dark:bg-red-900/20 border-red-400 dark:border-red-700", label: "경고", description: "해결 불가능한 위험 항목이 있습니다" },
    incomplete: { color: "text-slate-500 dark:text-slate-400", bg: "bg-slate-100 dark:bg-slate-800/50 border-slate-400 dark:border-slate-600", label: "미평가", description: "아직 평가된 항목이 없습니다" }
  }.freeze

  def initialize(rating:, fully_evaluated: true, tabs_evaluated: nil, tabs_total: nil)
    @config = RATING_CONFIG[rating] || RATING_CONFIG[:incomplete]
    @fully_evaluated = fully_evaluated
    @tabs_evaluated = tabs_evaluated
    @tabs_total = tabs_total
  end

  private

  def display_label
    if @fully_evaluated || @config[:label] == "미평가"
      @config[:label]
    else
      "#{@config[:label]} (진행 중)"
    end
  end

  def partial?
    !@fully_evaluated && @config[:label] != "미평가"
  end

  def progress_text
    return nil unless @tabs_evaluated && @tabs_total && !@fully_evaluated
    "#{@tabs_total}개 중 #{@tabs_evaluated}개 탭 분석 완료"
  end
end
```

- [ ] **Step 2: Update the template**

Replace `app/components/grade_summary_component.html.erb`:

```erb
<div class="rounded-xl border-2 p-8 text-center <%= @config[:bg] %>">
  <div class="text-4xl font-bold <%= @config[:color] %> <%= 'opacity-75' if partial? %>"><%= display_label %></div>
  <p class="mt-2 text-sm text-slate-600 dark:text-slate-400"><%= @config[:description] %></p>
  <% if (progress = progress_text) %>
    <p class="mt-1 text-xs text-slate-500 dark:text-slate-400"><%= progress %></p>
  <% end %>
</div>
```

- [ ] **Step 3: Update GradesController to pass partial evaluation data**

In `app/controllers/inspections/grades_controller.rb`, update the `show` action to compute and pass partial evaluation info. Replace the `@rating = ...` line and add helpers:

Replace:
```ruby
@rating = InspectionRatingService.call(property: @property, user: current_user)
```

With:
```ruby
rating_service = InspectionRatingService.new(property: @property, user: current_user)
@rating = rating_service.call
@fully_evaluated = rating_service.fully_evaluated?
@tabs_evaluated, @tabs_total = rating_service.tabs_evaluated_count
```

- [ ] **Step 4: Update the grades show view to pass new params**

In `app/views/inspections/grades/show.html.erb`, update the `GradeSummaryComponent` render:

Replace:
```erb
<%= render GradeSummaryComponent.new(rating: @rating) %>
```

With:
```erb
<%= render GradeSummaryComponent.new(rating: @rating, fully_evaluated: @fully_evaluated, tabs_evaluated: @tabs_evaluated, tabs_total: @tabs_total) %>
```

- [ ] **Step 5: Verify in browser**

1. With some tabs answered: navigate to 종합판정 — confirm "안전 (진행 중)" with opacity-75 and "5개 중 N개 탭 분석 완료"
2. With all items answered: confirm "안전" without "(진행 중)" and full opacity
3. With no items answered: confirm "미평가"

- [ ] **Step 6: Commit**

```bash
git add app/components/grade_summary_component.rb app/components/grade_summary_component.html.erb app/controllers/inspections/grades_controller.rb app/views/inspections/grades/show.html.erb
git commit -m "feat: show partial evaluation state in grade summary"
```

---

### Task 11: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: ALL PASS

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Fix any issues found**

If tests or rubocop report issues, fix them and commit:

```bash
git add -A
git commit -m "fix: address test/lint issues from partial grading implementation"
```

- [ ] **Step 4: Final browser verification**

Complete end-to-end flow:
1. Open a property → go to a tab (e.g., 권리분석)
2. Answer 2 out of N items → click 저장하기
3. Confirm: banner shows "안전" + "미응답 N개"
4. Confirm: tab navigation shows amber badge with unanswered count
5. Click 종합판정 tab
6. Confirm: grade shows "안전 (진행 중)" with progress info
7. Go back, answer remaining items, save
8. Confirm: banner shows no unanswered message
9. Confirm: tab badge no longer shows amber count
10. Click 종합판정 → confirm: "안전" (full, no "(진행 중)")
