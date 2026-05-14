# F03 Unified Results Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the `manual_inputs` step into the `results` page with source-type-aware input UI — auto items show "해결 가능/불가" directly, manual items show "예/아니오" first with conditional "해결 가능/불가".

**Architecture:** `ChecklistItemComponent` gains source-type branching to render different input sections. A rewritten `resolution_input_controller.js` Stimulus controller handles manual item toggling, card style changes, and form validation. `ResultsController#update` processes both `has_risk` and `resolvable` in a single form submission. The `manual_inputs` controller/view/route/test are deleted.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus (pure JS), TailwindCSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-06-f03-unified-results-page-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `app/components/checklist_item_component.rb` | Source-type branching logic, card state helpers |
| Modify | `app/components/checklist_item_component.html.erb` | Conditional input sections per source type |
| Rewrite | `app/javascript/controllers/resolution_input_controller.js` | Manual toggle, card style swap, form validation |
| Modify | `app/controllers/analyses/results_controller.rb` | Handle `has_risk` + `resolvable` + `resolution_note` |
| Modify | `app/controllers/analyses/start_controller.rb` | Always redirect to results |
| Modify | `app/services/property_analysis_service.rb` | Remove `pending_manual_items` return value |
| Modify | `config/routes.rb` | Remove `manual_input` resource |
| Modify | `test/fixtures/checklist_items.yml` | Add manual-type fixture |
| Modify | `test/fixtures/property_check_results.yml` | Add manual-type result fixtures |
| Modify | `test/components/checklist_item_component_test.rb` | Tests for all 5 card states |
| Modify | `test/controllers/analyses/results_controller_test.rb` | Tests for unified update action |
| Modify | `test/controllers/analyses/start_controller_test.rb` | Verify always redirects to results |
| Modify | `test/integration/property_analysis_flow_test.rb` | Unified flow (no manual_inputs step) |
| Delete | `app/controllers/analyses/manual_inputs_controller.rb` | No longer needed |
| Delete | `app/views/analyses/manual_inputs/edit.html.erb` | No longer needed |
| Delete | `app/javascript/controllers/manual_input_controller.js` | No longer needed |
| Delete | `test/controllers/analyses/manual_inputs_controller_test.rb` | No longer needed |

---

## Task 1: Add Manual Checklist Item Fixture

**Files:**
- Modify: `test/fixtures/checklist_items.yml`
- Modify: `test/fixtures/property_check_results.yml`

- [ ] **Step 1: Add a manual-type checklist item fixture**

Add to `test/fixtures/checklist_items.yml`:

```yaml
manual_001:
  code: "manual-001"
  category: "권리분석"
  risk_axis: 0
  question: "전입신고가 되어 있는 임차인이 존재합니까? (채무자/소유자만 거주 시 No)"
  description: "대항력 있는 임차인이 있으면 보증금 인수 리스크가 생깁니다."
  logic: '{"yes": "임차인 보증금 인수 리스크가 있습니다.", "no": "안전합니다."}'
  data_source_name: ""
  priority: "상"
  position: 8
```

- [ ] **Step 2: Add manual-type property check result fixtures**

Add to `test/fixtures/property_check_results.yml`:

```yaml
manual_unanswered_apartment_manual_001:
  property: safe_apartment
  checklist_item: manual_001
  user: guest
  source_type:
  has_risk:

manual_risk_villa_manual_001:
  property: risky_villa
  checklist_item: manual_001
  user: guest
  source_type: 1
  has_risk: true
  resolvable: true
  resolution_note: "임차인과 협의 완료"
```

- [ ] **Step 3: Run tests to confirm fixtures load**

Run: `bin/rails test test/components/checklist_item_component_test.rb -v`
Expected: All existing tests PASS (fixtures don't break anything)

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/checklist_items.yml test/fixtures/property_check_results.yml
git commit -m "test: add manual-type checklist item and result fixtures"
```

---

## Task 2: Update ChecklistItemComponent (Ruby + Template)

**Files:**
- Modify: `app/components/checklist_item_component.rb`
- Modify: `app/components/checklist_item_component.html.erb`
- Modify: `test/components/checklist_item_component_test.rb`

- [ ] **Step 1: Write failing tests for all 5 card states**

Replace the contents of `test/components/checklist_item_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class ChecklistItemComponentTest < ViewComponent::TestCase
  test "auto safe: renders green card with no input" do
    result = property_check_results(:safe_apartment_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "안전"
    assert_selector "[data-source-badge]", text: "AUTO"
    assert_no_selector "input[type='radio']"
  end

  test "auto risk: renders red card with resolution input" do
    result = property_check_results(:risky_villa_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "위험"
    assert_selector "[data-source-badge]", text: "AUTO"
    assert_selector "input[type='radio'][value='true']"  # resolvable=true
    assert_selector "input[type='radio'][value='false']"  # resolvable=false
  end

  test "manual unanswered: renders gray card with yes/no input" do
    result = property_check_results(:manual_unanswered_apartment_manual_001)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "미입력"
    assert_selector "[data-source-badge]", text: "직접 확인"
    assert_selector "input[type='radio'][value='true']"  # has_risk=true (예)
    assert_selector "input[type='radio'][value='false']"  # has_risk=false (아니오)
  end

  test "manual risk confirmed: renders yellow card with resolution sub-section" do
    result = property_check_results(:manual_risk_villa_manual_001)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "위험 확인"
    assert_selector "[data-resolution-section]"
  end

  test "show_resolution false: no input rendered for any type" do
    result = property_check_results(:risky_villa_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: false))
    assert_text "위험"
    assert_no_selector "input[type='radio']"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/checklist_item_component_test.rb -v`
Expected: FAIL — new tests fail because component doesn't have source-type logic yet

- [ ] **Step 3: Implement ChecklistItemComponent Ruby with source-type branching**

Replace the contents of `app/components/checklist_item_component.rb`:

```ruby
# frozen_string_literal: true

class ChecklistItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @checklist_item = result.checklist_item
    @show_resolution = show_resolution
  end

  private

  def auto_source?
    @result.source_type == "auto"
  end

  def manual_source?
    !auto_source?
  end

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      if auto_source?
        "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20"
      else
        "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
      end
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_classes
    if auto_source?
      if @result.has_risk
        "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300"
      else
        "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
      end
    else
      if @result.has_risk.nil?
        "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      elsif @result.has_risk
        "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300"
      else
        "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
      end
    end
  end

  def source_badge_text
    auto_source? ? "AUTO" : "직접 확인"
  end

  def status_text
    if manual_source? && @result.has_risk.nil?
      "미입력"
    elsif @result.has_risk
      auto_source? ? "위험" : "위험 확인"
    else
      "안전"
    end
  end

  def status_color
    if manual_source? && @result.has_risk.nil?
      "text-slate-500 dark:text-slate-400"
    elsif @result.has_risk
      auto_source? ? "text-red-700 dark:text-red-400" : "text-yellow-700 dark:text-yellow-400"
    else
      "text-green-700 dark:text-green-400"
    end
  end

  def show_auto_resolution?
    @show_resolution && auto_source? && @result.has_risk
  end

  def show_manual_input?
    @show_resolution && manual_source?
  end
end
```

- [ ] **Step 4: Replace template with source-type-aware rendering**

Replace the contents of `app/components/checklist_item_component.html.erb`:

```erb
<div class="rounded-lg border p-4 <%= risk_classes %>"
     data-controller="resolution-input"
     data-resolution-input-result-id-value="<%= @result.id %>"
     data-resolution-input-source-value="<%= auto_source? ? 'auto' : 'manual' %>">
  <div class="flex items-start justify-between">
    <div class="flex items-center gap-2">
      <span data-source-badge class="inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-semibold <%= source_badge_classes %>"><%= source_badge_text %></span>
      <p class="text-sm font-medium text-slate-900 dark:text-slate-100"><%= @checklist_item.question %></p>
    </div>
    <span class="ml-2 shrink-0 text-xs font-semibold <%= status_color %>" data-resolution-input-target="statusLabel"><%= status_text %></span>
  </div>
  <% if @checklist_item.description.present? %>
    <p class="mt-1 text-xs text-slate-500 dark:text-slate-400"><%= @checklist_item.description %></p>
  <% end %>

  <%# Auto risk: show resolution input directly %>
  <% if show_auto_resolution? %>
    <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가
        </label>
      </div>
      <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
          placeholder: "해결 방안 메모",
          class: "mt-2 w-full rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 text-sm placeholder:text-slate-400 dark:placeholder:text-slate-500" %>
    </div>
  <% end %>

  <%# Manual: show yes/no input with conditional resolution sub-section %>
  <% if show_manual_input? %>
    <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "true", @result.has_risk == true,
              data: { action: "change->resolution-input#toggleManualRisk" }, class: "mr-1.5" %> 예
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "false", @result.has_risk == false,
              data: { action: "change->resolution-input#toggleManualRisk" }, class: "mr-1.5" %> 아니오
        </label>
      </div>

      <div data-resolution-input-target="resolutionSection" data-resolution-section
           class="<%= 'hidden' unless @result.has_risk %> mt-3 rounded-md border border-dashed border-yellow-400 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20 p-3">
        <p class="mb-2 text-xs font-medium text-yellow-800 dark:text-yellow-300">↳ 해결 가능 여부를 선택해주세요:</p>
        <div class="flex items-center gap-4">
          <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
            <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능
          </label>
          <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
            <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가
          </label>
        </div>
        <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
            placeholder: "해결 방안 메모",
            class: "mt-2 w-full rounded-md border-yellow-300 dark:border-yellow-600 dark:bg-slate-700 dark:text-slate-200 text-sm placeholder:text-slate-400 dark:placeholder:text-slate-500" %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run component tests**

Run: `bin/rails test test/components/checklist_item_component_test.rb -v`
Expected: All 5 tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/checklist_item_component.rb app/components/checklist_item_component.html.erb test/components/checklist_item_component_test.rb
git commit -m "feat: add source-type-aware rendering to ChecklistItemComponent"
```

---

## Task 3: Rewrite Stimulus Controller

**Files:**
- Rewrite: `app/javascript/controllers/resolution_input_controller.js`

- [ ] **Step 1: Rewrite resolution_input_controller.js**

Replace the contents of `app/javascript/controllers/resolution_input_controller.js`:

```javascript
// app/javascript/controllers/resolution_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["resolutionSection", "statusLabel"]
  static values = { resultId: Number, source: String }

  // Card style class sets keyed by state
  static cardStyles = {
    gray: "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50",
    green: "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20",
    yellow: "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20",
    red: "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20"
  }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    if (hasRisk) {
      this.showResolutionSection()
      this.setCardStyle("yellow")
      this.updateStatus("위험 확인", "text-yellow-700 dark:text-yellow-400")
    } else {
      this.hideResolutionSection()
      this.setCardStyle("green")
      this.updateStatus("안전", "text-green-700 dark:text-green-400")
    }

    this.dispatchValidation()
  }

  showResolutionSection() {
    if (!this.hasResolutionSectionTarget) return
    this.resolutionSectionTarget.classList.remove("hidden")
  }

  hideResolutionSection() {
    if (!this.hasResolutionSectionTarget) return
    this.resolutionSectionTarget.classList.add("hidden")
    // Clear resolvable and note when hiding
    this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
    this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
  }

  setCardStyle(style) {
    const card = this.element
    // Remove all card style classes
    Object.values(this.constructor.cardStyles).forEach(classes => {
      classes.split(" ").forEach(c => card.classList.remove(c))
    })
    // Add new style classes
    this.constructor.cardStyles[style].split(" ").forEach(c => card.classList.add(c))
  }

  updateStatus(text, colorClasses) {
    if (!this.hasStatusLabelTarget) return
    this.statusLabelTarget.textContent = text
    // Remove all possible status color classes
    this.statusLabelTarget.className = this.statusLabelTarget.className
      .replace(/text-\S+/g, "")
      .trim()
    colorClasses.split(" ").forEach(c => this.statusLabelTarget.classList.add(c))
    // Re-add base classes
    this.statusLabelTarget.classList.add("ml-2", "shrink-0", "text-xs", "font-semibold")
  }

  dispatchValidation() {
    this.dispatch("changed", { bubbles: true })
  }
}
```

- [ ] **Step 2: Run full test suite to check nothing breaks**

Run: `bin/rails test -v`
Expected: All tests PASS (Stimulus is JS, not tested in Minitest — but check for no regressions)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/resolution_input_controller.js
git commit -m "feat: rewrite resolution_input_controller with manual item toggle and card styles"
```

---

## Task 4: Add Form Validation Stimulus Controller

**Files:**
- Modify: `app/javascript/controllers/resolution_input_controller.js` (add form-level controller)
- Modify: `app/views/analyses/results/edit.html.erb`

- [ ] **Step 1: Create unified_form_controller.js for form validation**

Create `app/javascript/controllers/unified_form_controller.js`:

```javascript
// app/javascript/controllers/unified_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton"]

  connect() {
    this.validate()
  }

  validate() {
    const manualCards = this.element.querySelectorAll("[data-resolution-input-source-value='manual']")
    let allValid = true

    manualCards.forEach(card => {
      const hasRiskRadios = card.querySelectorAll("input[name*='[has_risk]']")
      const hasRiskChecked = Array.from(hasRiskRadios).some(r => r.checked)

      if (!hasRiskChecked) {
        allValid = false
        return
      }

      const selectedYes = Array.from(hasRiskRadios).find(r => r.checked)?.value === "true"
      if (selectedYes) {
        const resolvableRadios = card.querySelectorAll("input[name*='[resolvable]']")
        const resolvableChecked = Array.from(resolvableRadios).some(r => r.checked)
        if (!resolvableChecked) {
          allValid = false
        }
      }
    })

    this.submitButtonTarget.disabled = !allValid
  }
}
```

- [ ] **Step 2: Update results/edit.html.erb to use both controllers**

Replace the contents of `app/views/analyses/results/edit.html.erb`:

```erb
<%# app/views/analyses/results/edit.html.erb %>
<%= turbo_frame_tag "analysis_flow" do %>
  <div class="space-y-6">
    <div>
      <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">분석 결과 및 해결 방안</h2>
      <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">모든 체크리스트 항목의 결과입니다. 위험 항목에 대해 해결 가능 여부를 입력해주세요.</p>
    </div>

    <%= form_with url: property_analyses_result_path(@property), method: :patch,
        data: { controller: "unified-form", action: "resolution-input:changed->unified-form#validate" } do |f| %>
      <div class="space-y-8">
        <% @results_by_axis.each do |axis, results| %>
          <%= render ChecklistGroupComponent.new(axis: axis, results: results, show_resolution: true) %>
        <% end %>
      </div>
      <div class="mt-6">
        <%= f.submit "등급 산정",
            class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed",
            data: { unified_form_target: "submitButton" } %>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 3: Run tests**

Run: `bin/rails test test/controllers/analyses/results_controller_test.rb -v`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/unified_form_controller.js app/views/analyses/results/edit.html.erb
git commit -m "feat: add unified form validation controller and update results view"
```

---

## Task 5: Update ResultsController to Handle Unified Params

**Files:**
- Modify: `app/controllers/analyses/results_controller.rb`
- Modify: `test/controllers/analyses/results_controller_test.rb`

- [ ] **Step 1: Write failing tests for unified update**

Replace the contents of `test/controllers/analyses/results_controller_test.rb`:

```ruby
require "test_helper"

class Analyses::ResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @current_user = User.find_by(email: "guest@auction.local")
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    @current_user.user_properties.find_or_create_by!(property: @property)
    PropertyAnalysisService.call(property: @property, user: @current_user)
  end

  test "GET edit shows all check results including manual items" do
    get edit_property_analyses_result_url(@property)
    assert_response :success
  end

  test "PATCH update saves auto item resolvable and redirects to rating" do
    auto_risk = @property.property_check_results
      .where(source_type: "auto", has_risk: true, user: @current_user).first

    # Mark all manual items as safe so form is complete
    @property.property_check_results.where(source_type: nil, user: @current_user).each do |r|
      r.update!(source_type: "manual", has_risk: false)
    end

    if auto_risk
      patch property_analyses_result_url(@property), params: {
        resolutions: { auto_risk.id => { resolvable: "false", resolution_note: "해결 불가" } }
      }
    else
      patch property_analyses_result_url(@property), params: { resolutions: {} }
    end
    assert_redirected_to property_analyses_rating_url(@property)
  end

  test "PATCH update saves manual item has_risk and resolvable" do
    manual_result = @property.property_check_results
      .where(source_type: nil, user: @current_user).first

    # Mark all other manual items as safe
    @property.property_check_results.where(source_type: nil, user: @current_user)
      .where.not(id: manual_result&.id).each { |r| r.update!(source_type: "manual", has_risk: false) }

    if manual_result
      resolutions = {
        manual_result.id => { has_risk: "true", resolvable: "true", resolution_note: "협의 완료" }
      }
      # Also include auto risk items
      @property.property_check_results
        .where(source_type: "auto", has_risk: true, user: @current_user).each do |r|
          resolutions[r.id] = { resolvable: "false", resolution_note: "" }
        end

      patch property_analyses_result_url(@property), params: { resolutions: resolutions }
      assert_redirected_to property_analyses_rating_url(@property)

      manual_result.reload
      assert_equal "manual", manual_result.source_type
      assert manual_result.has_risk
      assert manual_result.resolvable
      assert_equal "협의 완료", manual_result.resolution_note
    end
  end

  test "PATCH update saves manual item as safe when has_risk is false" do
    manual_result = @property.property_check_results
      .where(source_type: nil, user: @current_user).first

    # Mark all other manual items as safe
    @property.property_check_results.where(source_type: nil, user: @current_user)
      .where.not(id: manual_result&.id).each { |r| r.update!(source_type: "manual", has_risk: false) }

    if manual_result
      resolutions = {
        manual_result.id => { has_risk: "false" }
      }
      @property.property_check_results
        .where(source_type: "auto", has_risk: true, user: @current_user).each do |r|
          resolutions[r.id] = { resolvable: "false", resolution_note: "" }
        end

      patch property_analyses_result_url(@property), params: { resolutions: resolutions }
      assert_redirected_to property_analyses_rating_url(@property)

      manual_result.reload
      assert_equal "manual", manual_result.source_type
      assert_not manual_result.has_risk
      assert_nil manual_result.resolvable
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyses/results_controller_test.rb -v`
Expected: FAIL — controller doesn't handle `has_risk` yet

- [ ] **Step 3: Update ResultsController#update**

Replace the contents of `app/controllers/analyses/results_controller.rb`:

```ruby
module Analyses
  class ResultsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .where(user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)

          if result.source_type == "auto"
            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            has_risk = values[:has_risk] == "true"
            attrs = { source_type: "manual", has_risk: has_risk }

            if has_risk
              attrs[:resolvable] = values[:resolvable] == "true"
              attrs[:resolution_note] = values[:resolution_note]
            else
              attrs[:resolvable] = nil
              attrs[:resolution_note] = nil
            end

            result.update!(attrs)
          end
        end
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses/results_controller_test.rb -v`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/analyses/results_controller.rb test/controllers/analyses/results_controller_test.rb
git commit -m "feat: update ResultsController to handle unified manual + auto params"
```

---

## Task 6: Update StartController and Routes

**Files:**
- Modify: `app/controllers/analyses/start_controller.rb`
- Modify: `app/services/property_analysis_service.rb`
- Modify: `config/routes.rb`
- Modify: `test/controllers/analyses/start_controller_test.rb`

- [ ] **Step 1: Write test that start always redirects to results**

Replace the contents of `test/controllers/analyses/start_controller_test.rb`:

```ruby
require "test_helper"

class Analyses::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
  end

  test "POST create runs analysis and always redirects to results" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    current_user = User.find_by(email: "guest@auction.local")
    current_user.user_properties.find_or_create_by!(property: property)
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_result_url(property)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyses/start_controller_test.rb -v`
Expected: FAIL — currently redirects to manual_inputs when pending items exist

- [ ] **Step 3: Update StartController**

Replace the contents of `app/controllers/analyses/start_controller.rb`:

```ruby
module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      PropertyAnalysisService.call(property: @property, user: current_user)
      redirect_to edit_property_analyses_result_url(@property)
    end
  end
end
```

- [ ] **Step 4: Simplify PropertyAnalysisService**

Replace the contents of `app/services/property_analysis_service.rb`:

```ruby
class PropertyAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    AutoCheckRunner.call(property: @property, user: @user)
  end
end
```

- [ ] **Step 5: Remove manual_input route**

In `config/routes.rb`, remove the `resource :manual_input` line. The analyses namespace block should become:

```ruby
    namespace :analyses do
      resource :start, only: [ :create ], controller: "start"
      resource :result, only: [ :edit, :update ], controller: "results"
      resource :rating, only: [ :show ], controller: "ratings"
    end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses/start_controller_test.rb -v`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/analyses/start_controller.rb app/services/property_analysis_service.rb config/routes.rb test/controllers/analyses/start_controller_test.rb
git commit -m "feat: simplify start controller to always redirect to results, remove manual_input route"
```

---

## Task 7: Delete Manual Inputs Code

**Files:**
- Delete: `app/controllers/analyses/manual_inputs_controller.rb`
- Delete: `app/views/analyses/manual_inputs/edit.html.erb`
- Delete: `app/javascript/controllers/manual_input_controller.js`
- Delete: `test/controllers/analyses/manual_inputs_controller_test.rb`

- [ ] **Step 1: Delete all manual_inputs files**

```bash
rm app/controllers/analyses/manual_inputs_controller.rb
rm app/views/analyses/manual_inputs/edit.html.erb
rmdir app/views/analyses/manual_inputs
rm app/javascript/controllers/manual_input_controller.js
rm test/controllers/analyses/manual_inputs_controller_test.rb
```

- [ ] **Step 2: Run full test suite to confirm no breakage**

Run: `bin/rails test -v`
Expected: All tests PASS — no remaining references to deleted files

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: remove manual_inputs controller, view, stimulus controller, and test"
```

---

## Task 8: Update Integration Test

**Files:**
- Modify: `test/integration/property_analysis_flow_test.rb`

- [ ] **Step 1: Rewrite integration test for unified flow**

Replace the contents of `test/integration/property_analysis_flow_test.rb`:

```ruby
require "test_helper"

class PropertyAnalysisFlowTest < ActionDispatch::IntegrationTest
  test "full analysis flow: list → analyze → unified results → rating" do
    get start_onboarding_url
    current_user = User.find_by(email: "guest@auction.local")

    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    current_user.user_properties.find_or_create_by!(property: property)

    # Start analysis → always redirects to results
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_result_url(property)
    follow_redirect!
    assert_response :success

    # Build unified resolutions params
    resolutions = {}

    # Auto risk items: set resolvable
    property.property_check_results.where(source_type: "auto", has_risk: true, user: current_user).each do |r|
      resolutions[r.id] = { resolvable: "false", resolution_note: "해결 불가" }
    end

    # Manual items: set has_risk + resolvable if risky
    property.property_check_results.where(source_type: nil, user: current_user).each do |r|
      resolutions[r.id] = { has_risk: "false" }
    end

    patch property_analyses_result_url(property), params: { resolutions: resolutions }
    assert_redirected_to property_analyses_rating_url(property)
    follow_redirect!
    assert_response :success

    # Verify rating was set
    user_property = current_user.user_properties.find_by(property: property)
    assert user_property&.safety_rating.present?
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `bin/rails test test/integration/property_analysis_flow_test.rb -v`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/integration/property_analysis_flow_test.rb
git commit -m "test: update integration test for unified results page flow"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test -v`
Expected: All tests PASS

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Run security check**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings

- [ ] **Step 4: Verify SafetyRatingService handles nil has_risk**

`SafetyRatingService` queries `where(has_risk: true)` which naturally excludes `nil` values, so unanswered manual items won't affect the rating. Verify with:

Run: `bin/rails test test/services/safety_rating_service_test.rb -v`
Expected: All 3 tests PASS (no changes needed to SafetyRatingService)

- [ ] **Step 5: Verify no dangling references to manual_inputs**

```bash
grep -r "manual_input" app/ config/ test/ --include="*.rb" --include="*.erb" --include="*.js" --include="*.yml"
```
Expected: No matches (all references removed)

- [ ] **Step 6: Commit any linter fixes if needed**

```bash
git add -A
git commit -m "chore: fix lint issues from unified results page implementation"
```
