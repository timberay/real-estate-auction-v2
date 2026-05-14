# Tab Rating Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a colored Korean text badge (안전/주의/경고) on each inspection tab after saving, and scroll to top on save.

**Architecture:** Extend `InspectionRatingService` with a `tab_rating` method that scopes the existing rating logic to a single tab. `InspectionTabsComponent` calls this method per tab and renders a badge. The controller redirect adds an anchor for scroll-to-top.

**Tech Stack:** Rails 8.1, ViewComponent, Tailwind CSS, Minitest

---

### Task 1: Add `tab_rating` method to InspectionRatingService

**Files:**
- Modify: `app/services/inspection_rating_service.rb`
- Modify: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Write failing tests for `tab_rating`**

Add these tests to `test/services/inspection_rating_service_test.rb`, after the existing tests:

```ruby
test "tab_rating returns nil when no results for tab" do
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_nil service.tab_rating("sale_document")
end

test "tab_rating returns incomplete when unanswered items exist in tab" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_equal :incomplete, service.tab_rating("sale_document")
end

test "tab_rating returns safe when all items in tab have no risk" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_equal :safe, service.tab_rating("sale_document")
end

test "tab_rating returns caution when risks are resolvable in tab" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_equal :caution, service.tab_rating("sale_document")
end

test "tab_rating returns danger when unresolvable risk in tab" do
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
  service = InspectionRatingService.new(property: @property, user: @user)
  assert_equal :danger, service.tab_rating("sale_document")
end

test "tab_rating scopes to specific tab only" do
  # @item is tab 0 (sale_document) — create a result for it
  InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
  service = InspectionRatingService.new(property: @property, user: @user)
  # sale_document should be danger
  assert_equal :danger, service.tab_rating("sale_document")
  # registry (tab 1) has no results, should be nil
  assert_nil service.tab_rating("registry")
end
```

Note: `@item` is fixture `rights_011` which is `tab: 0` (sale_document). These tests reuse the existing setup block.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: 6 failures — `NoMethodError: undefined method 'tab_rating'`

- [ ] **Step 3: Implement `tab_rating` method**

In `app/services/inspection_rating_service.rb`, add the `tab_rating` method after the `call` method:

```ruby
def tab_rating(tab_key)
  tab_int = InspectionItem.tabs[tab_key]
  results = @property.inspection_results
    .joins(:inspection_item)
    .where(inspection_items: { tab: tab_int }, user: @user)

  return nil if results.empty?
  return :incomplete if results.exists?(has_risk: nil)

  risk_results = results.where(has_risk: true)

  if risk_results.exists?(resolvable: false)
    :danger
  elsif risk_results.any?
    :caution
  else
    :safe
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: All 10 tests pass (4 existing + 6 new)

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: add tab_rating method to InspectionRatingService"
```

---

### Task 2: Add rating data to InspectionTabsComponent

**Files:**
- Modify: `app/components/inspection_tabs_component.rb`

- [ ] **Step 1: Update `tabs` method to include rating**

Replace the `tabs` method in `app/components/inspection_tabs_component.rb`:

```ruby
def tabs
  rating_service = InspectionRatingService.new(property: @property, user: @user)
  TAB_CONFIG.map do |tab|
    counts = tab_counts(tab[:key])
    tab.merge(
      active: tab[:key] == @active_tab,
      url: tab_url(tab[:key]),
      checked: counts[:checked],
      total: counts[:total],
      rating: tab[:key] == "grade" ? nil : rating_service.tab_rating(tab[:key])
    )
  end
end
```

- [ ] **Step 2: Add `rating_badge_classes` helper method**

Add this private method below `tab_url` in `app/components/inspection_tabs_component.rb`:

```ruby
RATING_BADGE = {
  safe: { label: "안전", classes: "bg-green-800 text-green-200" },
  caution: { label: "주의", classes: "bg-yellow-800 text-yellow-200" },
  danger: { label: "경고", classes: "bg-red-800 text-red-200" }
}.freeze

def rating_badge(rating)
  RATING_BADGE[rating]
end
```

- [ ] **Step 3: Run existing tests to verify no regressions**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add app/components/inspection_tabs_component.rb
git commit -m "feat: add rating data to InspectionTabsComponent"
```

---

### Task 3: Render badge in tab template

**Files:**
- Modify: `app/components/inspection_tabs_component.html.erb`

- [ ] **Step 1: Update template to render badge before tab label**

Replace the full contents of `app/components/inspection_tabs_component.html.erb`:

```erb
<nav class="mb-4 overflow-x-auto">
  <div class="flex gap-1 text-sm min-w-max">
    <% tabs.each do |tab| %>
      <%= link_to tab[:url],
          class: "px-3 py-2 rounded-md transition-colors whitespace-nowrap #{tab[:active] ? 'bg-blue-600 text-white font-semibold' : 'bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-slate-200'}" do %>
        <% if (badge = rating_badge(tab[:rating])) %>
          <span class="<%= badge[:classes] %> text-[10px] font-semibold px-1.5 py-0.5 rounded"><%= badge[:label] %></span>
        <% end %>
        <span><%= tab[:label] %></span>
        <% if tab[:total] > 0 %>
          <span class="ml-1 text-xs <%= tab[:active] ? 'text-blue-200' : 'text-slate-500' %>"><%= tab[:checked] %>/<%= tab[:total] %></span>
        <% end %>
      <% end %>
    <% end %>
  </div>
</nav>
```

- [ ] **Step 2: Run all tests**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add app/components/inspection_tabs_component.html.erb
git commit -m "feat: render rating badge in inspection tab labels"
```

---

### Task 4: Scroll to top after save

**Files:**
- Modify: `app/controllers/inspections/tabs_controller.rb`
- Modify: `app/views/inspections/tabs/edit.html.erb`

- [ ] **Step 1: Add anchor to redirect in controller**

In `app/controllers/inspections/tabs_controller.rb`, change line 50:

From:
```ruby
redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key)
```

To:
```ruby
redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key, anchor: "top")
```

- [ ] **Step 2: Add `id="top"` anchor to edit view**

In `app/views/inspections/tabs/edit.html.erb`, add an anchor div as the first element inside the form, wrapping the existing content:

```erb
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: @tab_key } do %>
  <div id="top"></div>
  <%= form_with url: property_inspections_tab_path(@property, tab_key: @tab_key), method: :patch, data: { turbo: false } do |f| %>
    <div class="space-y-6">
      <% @results.group_by { |r| r.inspection_item.category }.each do |category, results| %>
        <%= render InspectionGroupComponent.new(category: category, results: results) %>
      <% end %>
    </div>
    <div class="mt-6">
      <%= f.submit "저장", class: "w-full rounded-lg bg-blue-600 px-4 py-3 text-sm font-semibold text-white hover:bg-blue-700 transition-colors" %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 3: Run all tests**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add app/controllers/inspections/tabs_controller.rb app/views/inspections/tabs/edit.html.erb
git commit -m "feat: scroll to top after saving inspection tab"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run dev server and verify all 7 scenarios**

Run: `bin/dev`

Navigate to a property's inspection tab (e.g., `/properties/:id/inspections/tabs/sale_document/edit`).

Verification checklist:
1. Save tab with all items answered as safe → green "안전" badge appears
2. Save tab with a resolvable risk → yellow "주의" badge appears
3. Save tab with an unresolvable risk → red "경고" badge appears
4. Tab with unanswered items → no badge
5. Tab never interacted with → no badge
6. After save, page scrolls to top
7. Grade tab (최종등급) never shows a badge

- [ ] **Step 2: Run full CI**

Run: `bin/ci`
Expected: All checks pass (rubocop, security, tests, seeds)
