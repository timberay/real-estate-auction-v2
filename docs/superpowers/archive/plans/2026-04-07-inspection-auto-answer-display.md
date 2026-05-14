# Inspection Auto-Answer Display & Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show yes/no logic explanations on every inspection item card, and allow users to override AUTO-detected answers inline.

**Architecture:** Extend `InspectionItemComponent` with logic display and edit-mode UI. Add Stimulus actions for edit/cancel toggle. Update `TabsController#update` to handle AUTO→manual overrides with `auto_value` preservation. No schema changes — all fields exist.

**Tech Stack:** Rails ViewComponent, Stimulus (pure JS), Minitest, existing Turbo form flow.

---

### Task 1: Add Badge & Logic Helper Methods to InspectionItemComponent

**Files:**
- Modify: `app/components/inspection_item_component.rb`
- Test: `test/components/inspection_item_component_test.rb`

- [ ] **Step 1: Create component test file with badge logic tests**

```ruby
# test/components/inspection_item_component_test.rb
require "test_helper"

class InspectionItemComponentTest < ViewComponent::TestCase
  test "renders AUTO badge for auto source" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "AUTO"
  end

  test "renders 직접 확인 badge for manual source without auto_value" do
    result = inspection_results(:manual_risk)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "직접 확인"
  end

  test "renders 수정됨 badge for manual source with auto_value" do
    result = inspection_results(:safe_apartment_rights_002)
    result.update!(source_type: "manual", auto_value: "false")
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "수정됨"
  end

  test "renders logic yes/no explanations when logic present" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    logic = result.inspection_item.logic
    assert_text logic["yes"]
    assert_text logic["no"]
  end

  test "highlights selected answer — yes when has_risk is false" do
    result = inspection_results(:safe_apartment_rights_002)
    assert_equal false, result.has_risk
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='yes']"
    refute_selector "[data-logic-selected='no']"
  end

  test "highlights selected answer — no when has_risk is true" do
    result = inspection_results(:risky_villa_rights_011)
    assert_equal true, result.has_risk
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='no']"
    refute_selector "[data-logic-selected='yes']"
  end

  test "no highlight when has_risk is nil" do
    result = inspection_results(:manual_unanswered)
    render_inline(InspectionItemComponent.new(result: result))

    refute_selector "[data-logic-selected]"
  end

  test "omits logic section when logic is blank" do
    result = inspection_results(:safe_apartment_rights_002)
    result.inspection_item.update!(logic: nil)
    render_inline(InspectionItemComponent.new(result: result))

    refute_selector "[data-logic-section]"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: FAIL — test file is new and methods don't exist yet

- [ ] **Step 3: Add helper methods to InspectionItemComponent**

Replace the entire `app/components/inspection_item_component.rb` with:

```ruby
class InspectionItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @item = result.inspection_item
    @show_resolution = show_resolution
  end

  private

  def auto_source? = @result.source_type == "auto"
  def manual_source? = !auto_source?
  def overridden? = manual_source? && @result.auto_value.present?

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_source? ? "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_text
    if auto_source?
      "AUTO"
    elsif overridden?
      "수정됨"
    else
      "직접 확인"
    end
  end

  def status_text
    if manual_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def show_auto_resolution? = @show_resolution && auto_source? && @result.has_risk
  def show_manual_input? = @show_resolution && manual_source?

  def logic_present? = @item.logic.present? && @item.logic["yes"].present?

  # Returns "yes", "no", or nil based on has_risk
  def selected_answer
    return nil if @result.has_risk.nil?
    @result.has_risk ? "no" : "yes"
  end
end
```

- [ ] **Step 4: Run tests to verify badge and logic helper tests pass**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: Some tests pass (helper logic), some fail (template assertions not yet updated)

- [ ] **Step 5: Commit**

```bash
git add app/components/inspection_item_component.rb test/components/inspection_item_component_test.rb
git commit -m "feat: add badge and logic helper methods to InspectionItemComponent"
```

---

### Task 2: Add Logic Display Section to Template

**Files:**
- Modify: `app/components/inspection_item_component.html.erb`

- [ ] **Step 1: Update template to show logic explanations**

Replace the entire `app/components/inspection_item_component.html.erb` with:

```erb
<div class="rounded-lg border p-4 <%= risk_classes %>"
     data-controller="inspection-item"
     data-inspection-item-result-id-value="<%= @result.id %>"
     data-inspection-item-auto-value="<%= auto_source? %>">
  <div class="flex items-start justify-between">
    <div class="flex items-center gap-2">
      <span class="inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
            data-inspection-item-target="sourceBadge"><%= source_badge_text %></span>
      <p class="text-sm font-medium text-slate-900 dark:text-slate-100"><%= @item.question %></p>
    </div>
    <div class="ml-2 flex shrink-0 items-center gap-2">
      <span class="text-xs font-semibold" data-inspection-item-target="statusLabel"><%= status_text %></span>
      <% if @show_resolution && auto_source? %>
        <button type="button"
                class="rounded border border-slate-300 px-2 py-0.5 text-xs text-slate-600 hover:bg-slate-100 dark:border-slate-500 dark:text-slate-300 dark:hover:bg-slate-700 transition-colors"
                data-inspection-item-target="editButton"
                data-action="click->inspection-item#enterEditMode">수정</button>
        <button type="button"
                class="hidden rounded border border-slate-300 px-2 py-0.5 text-xs text-slate-600 hover:bg-slate-100 dark:border-slate-500 dark:text-slate-300 dark:hover:bg-slate-700 transition-colors"
                data-inspection-item-target="cancelButton"
                data-action="click->inspection-item#cancelEditMode">취소</button>
      <% end %>
    </div>
  </div>
  <% if @item.description.present? %>
    <p class="mt-1 text-xs text-slate-500 dark:text-slate-400"><%= @item.description %></p>
  <% end %>

  <% if logic_present? %>
    <div class="mt-2 space-y-1 text-xs" data-logic-section>
      <div class="flex items-start gap-1.5 rounded px-2 py-1
                  <%= selected_answer == 'yes' ? 'bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300' : 'text-slate-400 dark:text-slate-500' %>"
           data-logic-selected="<%= 'yes' if selected_answer == 'yes' %>"
           data-inspection-item-target="logicYes">
        <span class="shrink-0" data-inspection-item-target="logicYesIcon"><%= selected_answer == "yes" ? "✔" : "○" %></span>
        <span>Yes: <%= @item.logic["yes"] %></span>
      </div>
      <div class="flex items-start gap-1.5 rounded px-2 py-1
                  <%= selected_answer == 'no' ? 'bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300' : 'text-slate-400 dark:text-slate-500' %>"
           data-logic-selected="<%= 'no' if selected_answer == 'no' %>"
           data-inspection-item-target="logicNo">
        <span class="shrink-0" data-inspection-item-target="logicNoIcon"><%= selected_answer == "no" ? "✔" : "○" %></span>
        <span>No: <%= @item.logic["no"] %></span>
      </div>
    </div>
  <% end %>

  <%# Edit mode: radio buttons for overriding AUTO answer (hidden by default) %>
  <% if @show_resolution && auto_source? %>
    <div class="mt-3 hidden border-t border-slate-200 dark:border-slate-600 pt-3"
         data-inspection-item-target="editSection">
      <p class="mb-2 text-xs font-medium text-slate-600 dark:text-slate-300">자동 수집 결과를 수정합니다:</p>
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "false", @result.has_risk == false,
              disabled: true,
              data: { action: "change->inspection-item#toggleManualRisk", inspection_item_target: "overrideRadio" },
              class: "mr-1.5" %> Yes (안전)
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "true", @result.has_risk == true,
              disabled: true,
              data: { action: "change->inspection-item#toggleManualRisk", inspection_item_target: "overrideRadio" },
              class: "mr-1.5" %> No (위험)
        </label>
      </div>
      <%# Hidden field to signal this is an override %>
      <input type="hidden" name="resolutions[<%= @result.id %>][override]" value="true" disabled
             data-inspection-item-target="overrideFlag">
      <div data-inspection-item-target="overrideResolutionSection" class="hidden mt-3 rounded-md border border-dashed border-yellow-400 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20 p-3">
        <p class="mb-2 text-xs font-medium text-yellow-800 dark:text-yellow-300">해결 가능 여부를 선택해주세요:</p>
        <div class="flex items-center gap-4">
          <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200">
            <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true,
                disabled: true,
                data: { inspection_item_target: "overrideRadio" },
                class: "mr-1.5" %> 해결 가능
          </label>
          <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200">
            <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false,
                disabled: true,
                data: { inspection_item_target: "overrideRadio" },
                class: "mr-1.5" %> 해결 불가
          </label>
        </div>
        <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
            disabled: true,
            placeholder: "해결 방안 메모",
            data: { inspection_item_target: "overrideInput" },
            class: "mt-2 w-full h-10 rounded-md border border-yellow-300 dark:border-yellow-600 bg-white dark:bg-slate-700 px-3 text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-colors" %>
      </div>
    </div>
  <% end %>

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
          class: "mt-2 w-full h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-200 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors" %>
    </div>
  <% end %>

  <% if show_manual_input? %>
    <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "true", @result.has_risk == true,
              data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 예
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "false", @result.has_risk == false,
              data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 아니오
        </label>
      </div>
      <div data-inspection-item-target="resolutionSection" class="<%= 'hidden' unless @result.has_risk %> mt-3 rounded-md border border-dashed border-yellow-400 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20 p-3">
        <p class="mb-2 text-xs font-medium text-yellow-800 dark:text-yellow-300">해결 가능 여부를 선택해주세요:</p>
        <div class="flex items-center gap-4">
          <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능</label>
          <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가</label>
        </div>
        <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
            placeholder: "해결 방안 메모",
            class: "mt-2 w-full h-10 rounded-md border border-yellow-300 dark:border-yellow-600 bg-white dark:bg-slate-700 px-3 text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-colors" %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Run component tests to verify logic display tests pass**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: All 8 tests PASS

- [ ] **Step 3: Run full test suite to check for regressions**

Run: `bin/rails test`
Expected: All existing tests still PASS

- [ ] **Step 4: Commit**

```bash
git add app/components/inspection_item_component.html.erb
git commit -m "feat: add logic display and edit button to inspection item template"
```

---

### Task 3: Stimulus Controller — Edit/Cancel Toggle for AUTO Items

**Files:**
- Modify: `app/javascript/controllers/inspection_item_controller.js`

- [ ] **Step 1: Update Stimulus controller with edit/cancel actions**

Replace the entire `app/javascript/controllers/inspection_item_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "resolutionSection", "statusLabel", "sourceBadge",
    "editButton", "cancelButton", "editSection",
    "overrideRadio", "overrideFlag", "overrideInput",
    "overrideResolutionSection",
    "logicYes", "logicNo", "logicYesIcon", "logicNoIcon"
  ]
  static values = { resultId: Number, auto: Boolean }

  // CSS class constants for logic highlight
  static LOGIC_YES_ACTIVE = "bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300".split(" ")
  static LOGIC_NO_ACTIVE = "bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300".split(" ")
  static LOGIC_DIMMED = "text-slate-400 dark:text-slate-500".split(" ")

  enterEditMode() {
    this.editButtonTarget.classList.add("hidden")
    this.cancelButtonTarget.classList.remove("hidden")
    this.editSectionTarget.classList.remove("hidden")
    this.sourceBadgeTarget.textContent = "수정됨"

    // Enable all override inputs so they submit with the form
    this.overrideRadioTargets.forEach(r => r.disabled = false)
    this.overrideFlagTarget.disabled = false
    this.overrideInputTargets.forEach(i => i.disabled = false)
  }

  cancelEditMode() {
    this.editButtonTarget.classList.remove("hidden")
    this.cancelButtonTarget.classList.add("hidden")
    this.editSectionTarget.classList.add("hidden")
    this.sourceBadgeTarget.textContent = "AUTO"

    // Disable and reset override inputs so they don't submit
    this.overrideRadioTargets.forEach(r => r.disabled = true)
    this.overrideFlagTarget.disabled = true
    this.overrideInputTargets.forEach(i => i.disabled = true)

    // Hide resolution subsection
    if (this.hasOverrideResolutionSectionTarget) {
      this.overrideResolutionSectionTarget.classList.add("hidden")
    }
  }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    // Update logic highlight to reflect the new selection
    this.#updateLogicHighlight(hasRisk)

    // Handle manual input section (existing behavior)
    if (this.hasResolutionSectionTarget) {
      if (hasRisk) {
        this.resolutionSectionTarget.classList.remove("hidden")
      } else {
        this.resolutionSectionTarget.classList.add("hidden")
        this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
        this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
      }
    }

    // Handle override resolution section (edit mode for AUTO items)
    if (this.hasOverrideResolutionSectionTarget) {
      if (hasRisk) {
        this.overrideResolutionSectionTarget.classList.remove("hidden")
      } else {
        this.overrideResolutionSectionTarget.classList.add("hidden")
        this.overrideResolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
        this.overrideResolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
      }
    }
  }

  // Private: update logic yes/no row highlighting based on selection
  #updateLogicHighlight(hasRisk) {
    if (!this.hasLogicYesTarget || !this.hasLogicNoTarget) return

    const yesEl = this.logicYesTarget
    const noEl = this.logicNoTarget
    const allActive = [...this.constructor.LOGIC_YES_ACTIVE, ...this.constructor.LOGIC_NO_ACTIVE]
    const dimmed = this.constructor.LOGIC_DIMMED

    // Reset both rows
    yesEl.classList.remove(...allActive, ...dimmed)
    noEl.classList.remove(...allActive, ...dimmed)
    yesEl.removeAttribute("data-logic-selected")
    noEl.removeAttribute("data-logic-selected")

    if (hasRisk) {
      // No selected (risk) — highlight No row, dim Yes row
      noEl.classList.add(...this.constructor.LOGIC_NO_ACTIVE)
      noEl.setAttribute("data-logic-selected", "no")
      yesEl.classList.add(...dimmed)
      this.logicNoIconTarget.textContent = "✔"
      this.logicYesIconTarget.textContent = "○"
    } else {
      // Yes selected (safe) — highlight Yes row, dim No row
      yesEl.classList.add(...this.constructor.LOGIC_YES_ACTIVE)
      yesEl.setAttribute("data-logic-selected", "yes")
      noEl.classList.add(...dimmed)
      this.logicYesIconTarget.textContent = "✔"
      this.logicNoIconTarget.textContent = "○"
    }
  }
}
```

- [ ] **Step 2: Run full test suite to check for regressions**

Run: `bin/rails test`
Expected: All tests PASS (JS changes don't break server-side tests)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/inspection_item_controller.js
git commit -m "feat: add edit/cancel toggle to inspection item Stimulus controller"
```

---

### Task 4: Controller — Handle AUTO Override in TabsController#update

**Files:**
- Modify: `app/controllers/inspections/tabs_controller.rb`
- Test: `test/controllers/inspections/tabs_controller_test.rb`

- [ ] **Step 1: Write failing test for AUTO override**

Add these tests to `test/controllers/inspections/tabs_controller_test.rb`:

```ruby
require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  test "edit renders tab items" do
    get edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    assert_response :success
  end

  test "edit returns 404 for invalid tab" do
    get edit_property_inspections_tab_url(@property, tab_key: "invalid")
    assert_response :not_found
  end

  test "override auto result changes source_type to manual and preserves auto_value" do
    auto_result = @property.inspection_results
      .where(user: users(:guest), source_type: "auto")
      .first

    original_has_risk = auto_result.has_risk
    new_has_risk = !original_has_risk
    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: new_has_risk.to_s
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal new_has_risk, auto_result.has_risk
    assert_equal original_has_risk.to_s, auto_result.auto_value
  end

  test "override auto result with risk includes resolvable and note" do
    auto_result = @property.inspection_results
      .where(user: users(:guest), source_type: "auto", has_risk: false)
      .first

    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: "true",
          resolvable: "true",
          resolution_note: "문서 재확인 결과 위험"
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal true, auto_result.has_risk
    assert_equal true, auto_result.resolvable
    assert_equal "문서 재확인 결과 위험", auto_result.resolution_note
    assert_equal "false", auto_result.auto_value
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/inspections/tabs_controller_test.rb`
Expected: 2 new tests FAIL — override logic not implemented yet

- [ ] **Step 3: Update TabsController#update to handle overrides**

Replace the entire `app/controllers/inspections/tabs_controller.rb` with:

```ruby
module Inspections
  class TabsController < ApplicationController
    VALID_TABS = %w[ sale_document registry building_ledger online field_visit etc ].freeze

    def edit
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      @results = @property.inspection_results
        .where(user: current_user)
        .joins(:inspection_item)
        .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] })
        .includes(:inspection_item)
        .order("inspection_items.tab_position")
    end

    def update
      @property = Property.find(params[:property_id])
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.inspection_results.where(user: current_user).find(id)

          if values[:override] == "true" && result.auto?
            apply_override(result, values)
          elsif result.auto?
            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            apply_manual_input(result, values)
          end
        end
      end

      redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key, anchor: "top")
    end

    private

    def apply_override(result, values)
      has_risk = values[:has_risk] == "true"
      attrs = {
        auto_value: result.has_risk.to_s,
        source_type: "manual",
        has_risk: has_risk
      }

      if has_risk
        attrs[:resolvable] = values[:resolvable] == "true"
        attrs[:resolution_note] = values[:resolution_note]
      else
        attrs[:resolvable] = nil
        attrs[:resolution_note] = nil
      end

      result.update!(attrs)
    end

    def apply_manual_input(result, values)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/inspections/tabs_controller_test.rb`
Expected: All 4 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/inspections/tabs_controller.rb test/controllers/inspections/tabs_controller_test.rb
git commit -m "feat: handle AUTO item override in TabsController with auto_value preservation"
```

---

### Task 5: Integration Test — Full Override Flow

**Files:**
- Modify: `test/integration/property_inspection_flow_test.rb`

- [ ] **Step 1: Add integration test for override flow**

Add this test to `test/integration/property_inspection_flow_test.rb`, after the existing tests:

```ruby
  test "override auto result preserves auto_value and shows as manual" do
    PropertyInspectionService.call(property: @property, user: @user)

    auto_result = @property.inspection_results
      .where(user: @user, source_type: "auto")
      .first

    assert_not_nil auto_result, "Expected at least one auto result"
    original_risk = auto_result.has_risk
    tab_key = auto_result.inspection_item.tab

    patch property_inspections_tab_url(@property, tab_key: tab_key), params: {
      resolutions: {
        auto_result.id => {
          override: "true",
          has_risk: (!original_risk).to_s
        }
      }
    }

    auto_result.reload
    assert_equal "manual", auto_result.source_type
    assert_equal !original_risk, auto_result.has_risk
    assert_equal original_risk.to_s, auto_result.auto_value

    # Verify it appears correctly on the tab page
    get edit_property_inspections_tab_url(@property, tab_key: tab_key)
    assert_response :success
    assert_select "span", text: "수정됨"
  end
```

- [ ] **Step 2: Run integration test**

Run: `bin/rails test test/integration/property_inspection_flow_test.rb`
Expected: All 3 tests PASS (new test exercises the full flow)

- [ ] **Step 3: Run full suite + rubocop**

Run: `bin/rails test && bin/rubocop`
Expected: All tests PASS, no rubocop offenses

- [ ] **Step 4: Commit**

```bash
git add test/integration/property_inspection_flow_test.rb
git commit -m "test: add integration test for auto result override flow"
```

---

### Task 6: Final Verification

- [ ] **Step 1: Run the complete CI pipeline**

Run: `bin/ci`
Expected: All checks pass (setup, rubocop, security audits, tests, seed check)

- [ ] **Step 2: Manual smoke test**

Run: `bin/dev`

1. Open a property's inspection page
2. Verify each AUTO item shows yes/no logic explanations
3. Verify the selected answer is highlighted (green for yes/safe, red for no/risk)
4. Click "수정" on an AUTO item — verify edit mode appears with radio buttons
5. Change the answer, click "저장" — verify badge changes to "수정됨"
6. Verify manual items still work as before (no regressions)
