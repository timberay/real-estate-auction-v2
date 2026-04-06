# Property List UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the properties index page with design-token-compliant input form, price tooltips, budget exceeded badge, and responsive 4-column grid.

**Architecture:** Extend existing ViewComponents (InputComponent, PropertyCardComponent, BadgeComponent) with new parameters. Add a lightweight Stimulus tooltip controller. Pass budget data from controller to view to component.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus (pure JS), Tailwind CSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-06-property-list-ui-improvements-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/components/input_component.rb` | Add `size:` parameter with padding map |
| Modify | `app/components/input_component.html.erb` | Apply size-based padding classes |
| Modify | `app/components/property_card_component.rb` | Add `max_bid_amount:` param, `budget_exceeded?` helper |
| Modify | `app/components/property_card_component.html.erb` | Price rows, tooltips, budget badge |
| Modify | `app/controllers/properties_controller.rb` | Pass `@max_bid_amount` to view |
| Modify | `app/views/properties/index.html.erb` | Use InputComponent, pass max_bid_amount, 4-col grid |
| Create | `app/javascript/controllers/tooltip_controller.js` | Stimulus controller for hover tooltips |
| Modify | `test/components/input_component_test.rb` | Tests for size parameter |
| Modify | `test/components/property_card_component_test.rb` | Tests for price layout, budget badge |
| Modify | `test/controllers/properties_controller_test.rb` | Test max_bid_amount assignment |

---

### Task 1: Add `size` parameter to InputComponent

**Files:**
- Modify: `app/components/input_component.rb`
- Modify: `app/components/input_component.html.erb`
- Modify: `test/components/input_component_test.rb`

- [ ] **Step 1: Write failing tests for size parameter**

Add to `test/components/input_component_test.rb`:

```ruby
# --- Size ---

test "renders default md size with py-2.5" do
  render_inline(InputComponent.new(label: "이름", name: "name"))

  assert_selector "input[class*='py-2.5']"
end

test "renders sm size with py-1.5" do
  render_inline(InputComponent.new(label: "이름", name: "name", size: :sm))

  assert_selector "input[class*='py-1.5']"
end

test "renders lg size with py-3" do
  render_inline(InputComponent.new(label: "이름", name: "name", size: :lg))

  assert_selector "input[class*='py-3']"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/input_component_test.rb`
Expected: 3 failures — `size` parameter not yet recognized, `py-2.5` not in current classes.

- [ ] **Step 3: Implement size parameter in InputComponent**

In `app/components/input_component.rb`, replace the full file with:

```ruby
# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  INPUT_CLASSES = "w-full rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
  NORMAL_CLASSES = "border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100"
  ERROR_CLASSES = "border-red-500"

  SIZES = {
    sm: "py-1.5",
    md: "py-2.5",
    lg: "py-3"
  }.freeze

  def initialize(label:, name:, type: "text", value: nil, required: false, error: nil, help_text: nil, suffix: nil, inputmode: nil, placeholder: nil, size: :md, **html_options)
    @label = label
    @name = name
    @type = type
    @value = value
    @required = required
    @error = error
    @help_text = help_text
    @suffix = suffix
    @inputmode = inputmode
    @placeholder = placeholder
    @size = size
    @html_options = html_options
  end

  private

  def input_classes
    class_names(
      INPUT_CLASSES,
      SIZES[@size],
      @error.present? ? ERROR_CLASSES : NORMAL_CLASSES
    )
  end

  def input_attributes
    attrs = {
      type: @type,
      name: @name,
      value: @value,
      class: input_classes,
      placeholder: @placeholder
    }
    attrs[:required] = true if @required
    attrs[:inputmode] = @inputmode if @inputmode
    attrs.merge(@html_options)
  end
end
```

Key change: removed `py-2` from `INPUT_CLASSES` constant, added `SIZES` hash, added `size:` param defaulting to `:md`, applied `SIZES[@size]` in `input_classes`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/input_component_test.rb`
Expected: ALL PASS. Note: existing tests that checked focus ring classes still pass because `focus:ring-2` and `focus:ring-blue-500/20` remain in `INPUT_CLASSES`.

- [ ] **Step 5: Commit**

```bash
git add app/components/input_component.rb test/components/input_component_test.rb
git commit -m "feat: add size parameter to InputComponent (sm/md/lg)"
```

- [ ] **Step 6: Update DESIGN.md to document size option**

In `~/.claude/skills/rails-ui/DESIGN.md`, find the Form Inputs section and add the size specification after the existing input specs:

```markdown
#### Input Sizes

| Size | Padding | Height | Use case |
|------|---------|--------|----------|
| `sm` | `py-1.5` | ~32px | Compact forms, inline filters |
| `md` (default) | `py-2.5` | ~40px | Standard forms, matches ButtonComponent md |
| `lg` | `py-3` | ~48px | Prominent inputs, landing pages |

Pass `size:` to `InputComponent`: `InputComponent.new(label: "...", name: "...", size: :md)`
```

- [ ] **Step 7: Commit DESIGN.md update**

```bash
git add ~/.claude/skills/rails-ui/DESIGN.md
git commit -m "docs: add input size option to DESIGN.md"
```

---

### Task 2: Redesign case number input form on properties index

**Files:**
- Modify: `app/views/properties/index.html.erb`

- [ ] **Step 1: Run existing controller tests to confirm baseline**

Run: `bin/rails test test/controllers/properties_controller_test.rb`
Expected: ALL PASS.

- [ ] **Step 2: Replace raw text_field with InputComponent and constrain width**

Replace the case number form section in `app/views/properties/index.html.erb` (lines 20-25). The full form block currently reads:

```erb
<%# Case number input form %>
<%= form_with url: properties_path, method: :post, class: "flex items-center gap-2" do |f| %>
  <%= f.text_field :case_number,
      placeholder: "경매번호를 입력하세요 (예: 2026타경1234)",
      class: "flex-1 rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 text-sm focus:ring-blue-500 focus:border-blue-500" %>
  <%= render ButtonComponent.new(type: "submit", icon: "plus") { "물건 추가" } %>
<% end %>
```

Replace with:

```erb
<%# Case number input form %>
<%= form_with url: properties_path, method: :post, class: "max-w-md" do |f| %>
  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">경매번호로 물건 추가</label>
  <div class="flex items-center gap-2">
    <%= f.text_field :case_number,
        placeholder: "예: 2026타경1234",
        class: "flex-1 rounded-md border px-3 py-2.5 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
    <%= render ButtonComponent.new(type: "submit", icon: "plus") { "추가" } %>
  </div>
  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원 경매 사건번호를 입력하세요</p>
<% end %>
```

Note: We use inline `text_field` with matching `py-2.5` classes rather than `InputComponent` rendering because the form layout (side-by-side input + button) doesn't fit `InputComponent`'s label-above-input structure. The classes match InputComponent's `md` size for visual consistency.

- [ ] **Step 3: Run controller tests to verify nothing broke**

Run: `bin/rails test test/controllers/properties_controller_test.rb`
Expected: ALL PASS. The form still POSTs `case_number` to `properties_path`.

- [ ] **Step 4: Commit**

```bash
git add app/views/properties/index.html.erb
git commit -m "refactor: redesign case number input form with label, help text, and constrained width"
```

---

### Task 3: Restructure price display in PropertyCardComponent

**Files:**
- Modify: `app/components/property_card_component.html.erb`
- Modify: `test/components/property_card_component_test.rb`

- [ ] **Step 1: Write failing tests for new price layout**

Add to `test/components/property_card_component_test.rb`:

```ruby
test "renders appraisal price label and value on separate line" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property))
  assert_selector "[data-price-type='appraisal']", text: "80,000만원"
  assert_text "감정가"
end

test "renders min bid price with label 최저매각가" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property))
  assert_selector "[data-price-type='min-bid']", text: "56,000만원"
  assert_text "최저매각가"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: 2 failures — `data-price-type` attributes don't exist yet.

- [ ] **Step 3: Update PropertyCardComponent template**

Replace the entire content of `app/components/property_card_component.html.erb` with:

```erb
<%= render CardComponent.new do |card| %>
  <div class="flex items-start justify-between">
    <div class="min-w-0 flex-1">
      <div class="flex items-center gap-2 flex-wrap">
        <%= link_to @property.case_number, property_path(@property),
            class: "text-base font-semibold text-slate-900 dark:text-slate-100 hover:text-blue-600 dark:hover:text-blue-400" %>
        <%= render SafetyBadgeComponent.new(rating: @safety_rating) %>
      </div>
      <p class="mt-1 text-sm text-slate-600 dark:text-slate-400 truncate"><%= @property.address %></p>
      <div class="mt-2 space-y-0.5">
        <div class="flex items-center justify-between text-sm" data-price-type="appraisal">
          <span class="text-slate-500 dark:text-slate-400"
                data-controller="tooltip"
                data-tooltip-content-value="감정평가사가 책정한 시장가치">
            감정가
            <svg class="inline w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </span>
          <span class="font-medium text-slate-700 dark:text-slate-300"><%= formatted_price(@property.appraisal_price) %></span>
        </div>
        <div class="flex items-center justify-between text-sm" data-price-type="min-bid">
          <span class="text-slate-500 dark:text-slate-400"
                data-controller="tooltip"
                data-tooltip-content-value="법원이 정한 최소 입찰금액">
            최저매각가
            <svg class="inline w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </span>
          <span class="font-medium text-slate-700 dark:text-slate-300"><%= formatted_price(@property.min_bid_price) %></span>
        </div>
      </div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: ALL PASS (new tests + existing tests for case_number, safety badge, address).

- [ ] **Step 5: Commit**

```bash
git add app/components/property_card_component.html.erb test/components/property_card_component_test.rb
git commit -m "refactor: restructure price display with labeled rows and tooltip data attributes"
```

---

### Task 4: Create tooltip Stimulus controller

**Files:**
- Create: `app/javascript/controllers/tooltip_controller.js`

- [ ] **Step 1: Create the tooltip controller**

Create `app/javascript/controllers/tooltip_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }

  connect() {
    this.tooltipElement = null
  }

  show() {
    if (this.tooltipElement) return

    this.tooltipElement = document.createElement("div")
    this.tooltipElement.className =
      "absolute z-10 px-2.5 py-1.5 text-xs font-medium text-white bg-slate-800 rounded-md shadow-sm dark:bg-slate-600 whitespace-nowrap pointer-events-none"
    this.tooltipElement.textContent = this.contentValue

    this.element.classList.add("relative")
    this.element.appendChild(this.tooltipElement)

    this.tooltipElement.style.bottom = "100%"
    this.tooltipElement.style.left = "50%"
    this.tooltipElement.style.transform = "translateX(-50%)"
    this.tooltipElement.style.marginBottom = "6px"
  }

  hide() {
    if (this.tooltipElement) {
      this.tooltipElement.remove()
      this.tooltipElement = null
    }
  }

  disconnect() {
    this.hide()
  }
}
```

- [ ] **Step 2: Add hover actions to the template**

Update the tooltip `span` elements in `app/components/property_card_component.html.erb`. Change both tooltip spans to include the `data-action` attribute. The appraisal price label span becomes:

```erb
          <span class="text-slate-500 dark:text-slate-400 cursor-help"
                data-controller="tooltip"
                data-tooltip-content-value="감정평가사가 책정한 시장가치"
                data-action="mouseenter->tooltip#show mouseleave->tooltip#hide">
```

The min bid price label span becomes:

```erb
          <span class="text-slate-500 dark:text-slate-400 cursor-help"
                data-controller="tooltip"
                data-tooltip-content-value="법원이 정한 최소 입찰금액"
                data-action="mouseenter->tooltip#show mouseleave->tooltip#hide">
```

- [ ] **Step 3: Verify Stimulus auto-registration**

Run: `grep -r "tooltip" app/javascript/controllers/index.js || echo "Using eagerLoadControllersFrom — auto-registered"`

The project uses `eagerLoadControllersFrom` in the Stimulus application setup, so `tooltip_controller.js` will be auto-discovered. No manual registration needed.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/tooltip_controller.js app/components/property_card_component.html.erb
git commit -m "feat: add tooltip Stimulus controller for price label hover explanations"
```

---

### Task 5: Add budget exceeded badge to PropertyCardComponent

**Files:**
- Modify: `app/components/property_card_component.rb`
- Modify: `app/components/property_card_component.html.erb`
- Modify: `test/components/property_card_component_test.rb`

- [ ] **Step 1: Write failing tests for budget exceeded badge**

Add to `test/components/property_card_component_test.rb`:

```ruby
test "renders budget exceeded badge when appraisal_price exceeds max_bid_amount" do
  property = properties(:safe_apartment) # appraisal_price: 80000
  render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 50000))
  assert_selector ".inline-flex", text: "예산 초과"
end

test "does not render budget exceeded badge when within budget" do
  property = properties(:safe_apartment) # appraisal_price: 80000
  render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 100000))
  assert_no_text "예산 초과"
end

test "does not render budget exceeded badge when max_bid_amount is nil" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property, max_bid_amount: nil))
  assert_no_text "예산 초과"
end

test "does not render budget exceeded badge when max_bid_amount not provided" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property))
  assert_no_text "예산 초과"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: At least 1 failure — `max_bid_amount` keyword not recognized.

- [ ] **Step 3: Add max_bid_amount parameter and budget_exceeded? helper**

Replace `app/components/property_card_component.rb` with:

```ruby
# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, safety_rating: nil, max_bid_amount: nil)
    @property = property
    @safety_rating = safety_rating
    @max_bid_amount = max_bid_amount
  end

  private

  def formatted_price(amount)
    return "—" unless amount
    number_to_currency(amount, unit: "", precision: 0, delimiter: ",") + "만원"
  end

  def budget_exceeded?
    @max_bid_amount.present? && @property.appraisal_price.present? && @property.appraisal_price > @max_bid_amount
  end
end
```

- [ ] **Step 4: Add badge rendering to the template**

In `app/components/property_card_component.html.erb`, add the budget exceeded badge inside the `flex items-center gap-2 flex-wrap` div, right after the SafetyBadgeComponent line:

```erb
      <div class="flex items-center gap-2 flex-wrap">
        <%= link_to @property.case_number, property_path(@property),
            class: "text-base font-semibold text-slate-900 dark:text-slate-100 hover:text-blue-600 dark:hover:text-blue-400" %>
        <%= render SafetyBadgeComponent.new(rating: @safety_rating) %>
        <% if budget_exceeded? %>
          <%= render BadgeComponent.new(variant: :warning) { "예산 초과" } %>
        <% end %>
      </div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add app/components/property_card_component.rb app/components/property_card_component.html.erb test/components/property_card_component_test.rb
git commit -m "feat: add budget exceeded warning badge to property card"
```

---

### Task 6: Pass max_bid_amount from controller to view to component

**Files:**
- Modify: `app/controllers/properties_controller.rb`
- Modify: `app/views/properties/index.html.erb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing test for max_bid_amount in controller**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
test "GET index assigns max_bid_amount from budget setting" do
  # budget_user has budget_setting with max_bid_amount: 96200
  # Log in as budget_user instead of guest
  post start_onboarding_url # reset session
  user = users(:budget_user)
  post session_url, params: { email: user.email, password: "123456" }

  get properties_url
  assert_response :success
end
```

Note: This test verifies the page renders successfully with a user who has a budget_setting. The actual badge rendering is already covered by component tests.

- [ ] **Step 2: Run tests to verify baseline**

Run: `bin/rails test test/controllers/properties_controller_test.rb`
Expected: Check if the new test passes or fails. If there's no `session_url` route, we may need to adjust the approach — the guest user flow may be sufficient.

- [ ] **Step 3: Add @max_bid_amount to properties controller index**

In `app/controllers/properties_controller.rb`, add one line to the `index` action:

```ruby
def index
  @user_properties = current_user.user_properties
    .includes(:property)
    .order(created_at: :desc)
  @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
  @max_bid_amount = current_user.budget_setting&.max_bid_amount
end
```

The only new line is: `@max_bid_amount = current_user.budget_setting&.max_bid_amount`

- [ ] **Step 4: Pass max_bid_amount to PropertyCardComponent in the view**

In `app/views/properties/index.html.erb`, update the card rendering inside the grid loop:

```erb
    <div class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
      <% @user_properties.each do |user_property| %>
        <%= render PropertyCardComponent.new(
          property: user_property.property,
          safety_rating: user_property.safety_rating,
          max_bid_amount: @max_bid_amount
        ) %>
      <% end %>
    </div>
```

Note: This step also applies the 4-column grid change (Task 7), since we're editing the same line. If you prefer to keep them separate, change only the `render` call here and handle grid in Task 7.

- [ ] **Step 5: Run all tests**

Run: `bin/rails test`
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/properties_controller.rb app/views/properties/index.html.erb test/controllers/properties_controller_test.rb
git commit -m "feat: pass max_bid_amount from controller through view to property card"
```

---

### Task 7: Update grid to responsive 4-column layout

**Files:**
- Modify: `app/views/properties/index.html.erb`

- [ ] **Step 1: Verify grid classes are updated**

If Task 6 Step 4 already changed the grid classes to `sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4`, this task is already done. Verify by reading the file.

If the grid still reads `sm:grid-cols-2 lg:grid-cols-3`, update it in `app/views/properties/index.html.erb`:

Change:
```erb
<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
```
To:
```erb
<div class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
```

- [ ] **Step 2: Run all tests**

Run: `bin/rails test`
Expected: ALL PASS.

- [ ] **Step 3: Commit (only if not already committed in Task 6)**

```bash
git add app/views/properties/index.html.erb
git commit -m "feat: update property grid to responsive 4-column layout"
```

---

### Task 8: Final verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: ALL PASS, 0 failures, 0 errors.

- [ ] **Step 2: Run RuboCop**

Run: `bin/rubocop`
Expected: No offenses detected. If there are offenses in modified files, fix them.

- [ ] **Step 3: Run Brakeman security check**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings.

- [ ] **Step 4: Manual verification checklist**

Start `bin/dev` and check:
1. Properties index: case number input has label "경매번호로 물건 추가", help text, and `max-w-md` width
2. Input field and "추가" button have the same height
3. Property cards show 감정가 and 최저매각가 on separate rows with values right-aligned
4. Hovering over price labels shows tooltip with explanation text
5. Resize browser: 1 col mobile → 2 col sm → 3 col md → 4 col lg
6. If user has budget_setting with max_bid_amount < property appraisal_price, "예산 초과" warning badge appears next to case number
