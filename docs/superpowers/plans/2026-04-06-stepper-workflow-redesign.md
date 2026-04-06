# Stepper Workflow Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken tab navigation with a chevron stepper that communicates a sequential analysis workflow (checklist → rights analysis → rating).

**Architecture:** Property detail card stays fixed above a 3-step chevron stepper. The stepper lives outside the Turbo Frame so it persists during content swaps. A Stimulus controller handles pending-step click interception and active-state updates. Analysis views render the full page layout (card + stepper + frame) instead of just frame content.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus (pure JS), Turbo Frames, TailwindCSS

**Spec:** `docs/superpowers/specs/2026-04-06-stepper-workflow-redesign.md`

---

## File Map

**Create:**
- `app/components/stepper_component.rb` — ViewComponent with step state logic
- `app/components/stepper_component.html.erb` — Chevron stepper template
- `app/javascript/controllers/stepper_controller.js` — Click interception for pending steps
- `app/views/analyses/_layout.html.erb` — Shared layout partial (compact card + stepper + frame)
- `app/views/analyses/_property_card_compact.html.erb` — Collapsed single-line property card
- `test/components/stepper_component_test.rb` — Component unit tests

**Modify:**
- `app/controllers/properties_controller.rb` — Add redirect logic for post-analysis entry
- `app/controllers/analyses/checklists_controller.rb` — Add `@active_step` and shared setup
- `app/controllers/analyses/reports_controller.rb` — Add `@active_step` and shared setup
- `app/controllers/analyses/ratings_controller.rb` — Add `@active_step` and shared setup
- `app/views/properties/show.html.erb` — Simplify to pre-analysis state only
- `app/views/analyses/checklists/edit.html.erb` — Use shared layout
- `app/views/analyses/reports/show.html.erb` — Use shared layout
- `app/views/analyses/ratings/show.html.erb` — Use shared layout
- `test/controllers/properties_controller_test.rb` — Add redirect tests
- `test/integration/property_analysis_flow_test.rb` — Update for new flow

**Delete:**
- `app/components/property_tabs_component.rb`
- `app/components/property_tabs_component.html.erb`
- `test/components/property_tabs_component_test.rb`
- `app/javascript/controllers/property_tabs_controller.js`

---

## Task 1: Create StepperComponent with Tests (TDD)

**Files:**
- Create: `test/components/stepper_component_test.rb`
- Create: `app/components/stepper_component.rb`
- Create: `app/components/stepper_component.html.erb`

- [ ] **Step 1: Write failing test for StepperComponent**

```ruby
# test/components/stepper_component_test.rb
require "test_helper"

class StepperComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "renders 3 steps with correct labels" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_text "체크리스트"
    assert_text "권리 분석"
    assert_text "등급 산정"
    assert_no_text "기본 정보"
  end

  test "marks active step with active status" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "[data-step-status='active']", text: "권리 분석"
  end

  test "marks completed steps with checkmark" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "[data-step-status='completed']", text: "체크리스트"
  end

  test "marks pending steps with pending status" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-step-status='pending']", text: "권리 분석"
    assert_selector "[data-step-status='pending']", text: "등급 산정"
  end

  test "completed steps are clickable links" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
    assert_selector "a[data-step-status='completed'][href]", text: "체크리스트"
  end

  test "pending steps have turbo frame target" do
    render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
    assert_selector "[data-turbo-frame='tab_content']", count: 3
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `eval "$(rbenv init -)" && bin/rails test test/components/stepper_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant StepperComponent`

- [ ] **Step 3: Create StepperComponent Ruby class**

```ruby
# app/components/stepper_component.rb
class StepperComponent < ViewComponent::Base
  STEPS = [
    { key: :checklist, number: 1, label: "체크리스트" },
    { key: :report,    number: 2, label: "권리 분석" },
    { key: :rating,    number: 3, label: "등급 산정" }
  ].freeze

  def initialize(property:, user:, active_step:)
    @property = property
    @user = user
    @active_step = active_step
  end

  private

  def steps
    STEPS.map do |step|
      step.merge(
        status: step_status(step[:key]),
        url: step_url(step[:key])
      )
    end
  end

  def step_status(key)
    if key == @active_step
      :active
    elsif step_completed?(key)
      :completed
    else
      :pending
    end
  end

  def step_completed?(key)
    case key
    when :checklist then user_property&.analyzed_at.present?
    when :report then report.present?
    when :rating then user_property&.safety_rating.present?
    end
  end

  def step_url(key)
    case key
    when :checklist then helpers.edit_property_analyses_checklist_path(@property)
    when :report then helpers.property_analyses_report_path(@property)
    when :rating then helpers.property_analyses_rating_path(@property)
    end
  end

  def user_property
    @user_property ||= UserProperty.find_by(user: @user, property: @property)
  end

  def report
    @report ||= RightsAnalysisReport.find_by(user: @user, property: @property)
  end
end
```

- [ ] **Step 4: Create StepperComponent template**

```erb
<%# app/components/stepper_component.html.erb %>
<nav class="mb-4 overflow-hidden rounded-md" data-controller="stepper">
  <div class="flex text-sm">
    <% steps.each_with_index do |step, index| %>
      <%= link_to step[:url],
          class: step_classes(step, index),
          data: {
            stepper_target: "step",
            step_status: step[:status],
            step_key: step[:key],
            turbo_frame: "tab_content",
            action: "click->stepper#navigate"
          } do %>
        <% if step[:status] == :completed %>
          <span class="text-xs">✓</span>
        <% else %>
          <span class="text-xs"><%= step[:number] %>.</span>
        <% end %>
        <span><%= step[:label] %></span>
      <% end %>
    <% end %>
  </div>
</nav>
```

Add `step_classes` helper to the Ruby class — append to `app/components/stepper_component.rb` inside the `private` block, before the `user_property` method:

```ruby
  def step_classes(step, index)
    base = "flex items-center justify-center gap-1.5 py-2.5 flex-1 transition-colors"

    # Chevron clip-path
    shape = if index == 0
      "[clip-path:polygon(0_0,calc(100%-14px)_0,100%_50%,calc(100%-14px)_100%,0_100%)]"
    elsif index == steps.length - 1
      "-ml-2.5 [clip-path:polygon(0_0,100%_0,100%_100%,0_100%,14px_50%)] rounded-r-md"
    else
      "-ml-2.5 [clip-path:polygon(0_0,calc(100%-14px)_0,100%_50%,calc(100%-14px)_100%,0_100%,14px_50%)]"
    end

    color = case step[:status]
    when :completed then "bg-blue-900/50 text-blue-300"
    when :active    then "bg-blue-600 text-white font-semibold"
    when :pending   then "bg-slate-800 text-slate-500"
    end

    "#{base} #{shape} #{color}"
  end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `eval "$(rbenv init -)" && bin/rails test test/components/stepper_component_test.rb`
Expected: All 6 tests PASS

- [ ] **Step 6: Commit**

```bash
eval "$(rbenv init -)" && git add app/components/stepper_component.rb app/components/stepper_component.html.erb test/components/stepper_component_test.rb && git commit -m "feat: add StepperComponent with chevron stepper UI

TDD: 6 tests covering step states, labels, and clickability"
```

---

## Task 2: Create Stimulus Stepper Controller

**Files:**
- Create: `app/javascript/controllers/stepper_controller.js`

- [ ] **Step 1: Create stepper Stimulus controller**

```javascript
// app/javascript/controllers/stepper_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step"]

  navigate(event) {
    const step = event.currentTarget
    const status = step.dataset.stepStatus

    if (status === "pending") {
      event.preventDefault()
      event.stopPropagation()
      this.showWarning(step)
      return
    }

    // Update active state visually for completed steps
    if (status === "completed") {
      this.updateActiveStep(step)
    }
  }

  showWarning(clickedStep) {
    const frame = document.getElementById("tab_content")
    if (!frame) return

    const key = clickedStep.dataset.stepKey
    const labels = { checklist: "체크리스트", report: "권리 분석", rating: "등급 산정" }

    // Find the previous step's label
    const steps = ["checklist", "report", "rating"]
    const clickedIndex = steps.indexOf(key)
    const previousKey = steps[clickedIndex - 1]
    const previousLabel = labels[previousKey] || "이전 단계"

    frame.innerHTML = `
      <div class="bg-slate-800 border border-amber-700 rounded-lg p-6 text-center">
        <p class="text-amber-500 font-medium mb-1">이전 단계를 먼저 완료해주세요</p>
        <p class="text-slate-400 text-sm">"${previousLabel}" 단계를 완료한 후 진행할 수 있습니다.</p>
      </div>
    `
  }

  updateActiveStep(clickedStep) {
    this.stepTargets.forEach(step => {
      const isClicked = step === clickedStep
      const status = step.dataset.stepStatus

      if (isClicked) {
        step.dataset.stepStatus = "active"
        step.classList.remove("bg-blue-900/50", "text-blue-300", "bg-slate-800", "text-slate-500")
        step.classList.add("bg-blue-600", "text-white", "font-semibold")
      } else if (status === "active") {
        // Previous active becomes completed
        step.dataset.stepStatus = "completed"
        step.classList.remove("bg-blue-600", "text-white", "font-semibold")
        step.classList.add("bg-blue-900/50", "text-blue-300")
      }
    })
  }
}
```

- [ ] **Step 2: Verify Stimulus controller is auto-registered**

Run: `eval "$(rbenv init -)" && grep -r "stepper" app/javascript/controllers/index.js 2>/dev/null; ls app/javascript/controllers/stepper_controller.js`

Stimulus auto-imports controllers from `app/javascript/controllers/` via `eagerLoadControllersFrom` in `application.js`. Verify:

Run: `eval "$(rbenv init -)" && grep -r "eagerLoad\|controllers" app/javascript/controllers/application.js`

- [ ] **Step 3: Commit**

```bash
eval "$(rbenv init -)" && git add app/javascript/controllers/stepper_controller.js && git commit -m "feat: add stepper Stimulus controller

Handles pending step click interception with warning message
and visual active state updates for completed step navigation"
```

---

## Task 3: Create Shared Analysis Layout Partials

**Files:**
- Create: `app/views/analyses/_property_card_compact.html.erb`
- Create: `app/views/analyses/_layout.html.erb`

- [ ] **Step 1: Create compact property card partial**

```erb
<%# app/views/analyses/_property_card_compact.html.erb %>
<div class="flex items-center justify-between bg-slate-800 rounded-lg px-4 py-3">
  <div class="flex items-center gap-2">
    <span class="text-base font-bold text-slate-100"><%= property.case_number %></span>
    <%= render SafetyBadgeComponent.new(rating: user_property&.safety_rating) %>
    <% if property.court_name.present? %>
      <span class="text-xs text-slate-400"><%= property.court_name %></span>
    <% end %>
  </div>
  <span class="text-xs text-slate-400"><%= format_price_in_eok(property.appraisal_price) %></span>
</div>
```

- [ ] **Step 2: Create shared analysis layout partial**

```erb
<%# app/views/analyses/_layout.html.erb %>
<div class="space-y-3">
  <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>

  <%= render "analyses/property_card_compact", property: property, user_property: user_property %>
  <%= render StepperComponent.new(property: property, user: current_user, active_step: active_step) %>

  <%= turbo_frame_tag "tab_content" do %>
    <%= yield %>
  <% end %>
</div>
```

- [ ] **Step 3: Verify partials render without errors**

Run: `eval "$(rbenv init -)" && bin/rails test test/components/stepper_component_test.rb`
Expected: PASS (no regressions)

- [ ] **Step 4: Commit**

```bash
eval "$(rbenv init -)" && git add app/views/analyses/_property_card_compact.html.erb app/views/analyses/_layout.html.erb && git commit -m "feat: add shared analysis layout partials

Compact property card and layout partial with stepper + turbo frame"
```

---

## Task 4: Update Analysis Controllers to Set @active_step

**Files:**
- Modify: `app/controllers/analyses/checklists_controller.rb:3`
- Modify: `app/controllers/analyses/reports_controller.rb:3`
- Modify: `app/controllers/analyses/ratings_controller.rb:4`

- [ ] **Step 1: Update ChecklistsController**

In `app/controllers/analyses/checklists_controller.rb`, add `@active_step` and `@user_property` to the `edit` action. Replace lines 3-10:

```ruby
    def edit
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @active_step = :checklist
      @results_by_axis = @property.property_check_results
        .where(user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end
```

- [ ] **Step 2: Update ReportsController**

In `app/controllers/analyses/reports_controller.rb`, add `@active_step` and `@user_property` to the `show` action. Replace lines 3-11:

```ruby
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @active_step = :report
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)

      unless @report
        redirect_to property_url(@property), alert: "권리 분석을 먼저 실행해주세요."
        nil
      end
    end
```

- [ ] **Step 3: Update RatingsController**

In `app/controllers/analyses/ratings_controller.rb`, add `@active_step` and `@user_property` to the `show` action. Replace lines 3-10:

```ruby
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @active_step = :rating
      @rating = SafetyRatingService.call(property: @property, user: current_user)
      @risk_results = @property.property_check_results
        .where(has_risk: true, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
```

- [ ] **Step 4: Run existing controller tests**

Run: `eval "$(rbenv init -)" && bin/rails test test/controllers/analyses/`
Expected: All PASS (no behavior change, just added instance variables)

- [ ] **Step 5: Commit**

```bash
eval "$(rbenv init -)" && git add app/controllers/analyses/ && git commit -m "feat: add @active_step and @user_property to analysis controllers

Each analysis controller now sets the active step for StepperComponent"
```

---

## Task 5: Update Analysis Views to Use Shared Layout

**Files:**
- Modify: `app/views/analyses/checklists/edit.html.erb`
- Modify: `app/views/analyses/reports/show.html.erb`
- Modify: `app/views/analyses/ratings/show.html.erb`

- [ ] **Step 1: Update checklists/edit.html.erb**

Replace the entire file:

```erb
<%# app/views/analyses/checklists/edit.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-6">
    <div>
      <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">분석 결과 및 해결 방안</h2>
      <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">모든 체크리스트 항목의 결과입니다. 위험 항목에 대해 해결 가능 여부를 입력해주세요.</p>
    </div>

    <%= form_with url: property_analyses_checklist_path(@property), method: :patch,
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

- [ ] **Step 2: Update reports/show.html.erb**

Replace the entire file:

```erb
<%# app/views/analyses/reports/show.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-8">
    <%= render ReportSummaryComponent.new(report: @report) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(property: @property) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

- [ ] **Step 3: Update ratings/show.html.erb**

Replace the entire file:

```erb
<%# app/views/analyses/ratings/show.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-6">
    <%= render RatingResultComponent.new(property: @property, risk_results: @risk_results, rating: @rating) %>

    <div class="flex justify-center gap-3">
      <%= button_to "다시 분석하기", property_analyses_start_path(@property), method: :post,
          class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" %>
      <%= link_to "목록으로 돌아가기", properties_path,
          class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700",
          data: { turbo_frame: "_top" } %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 4: Run integration test to verify flow still works**

Run: `eval "$(rbenv init -)" && bin/rails test test/integration/property_analysis_flow_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
eval "$(rbenv init -)" && git add app/views/analyses/ && git commit -m "feat: update analysis views to use shared layout with stepper

All analysis views now render compact card + stepper + turbo frame"
```

---

## Task 6: Update PropertiesController#show and View

**Files:**
- Modify: `app/controllers/properties_controller.rb:20-27`
- Modify: `app/views/properties/show.html.erb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing tests for redirect logic**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
  test "GET show redirects to rating when analysis complete" do
    property = properties(:safe_apartment)
    user_property = user_properties(:guest_safe_apartment)
    user_property.update!(analyzed_at: Time.current)

    get property_url(property)
    assert_redirected_to property_analyses_rating_path(property)
  end

  test "GET show redirects to checklist when analysis started but no rating" do
    property = properties(:safe_apartment)
    user_property = user_properties(:guest_safe_apartment)
    user_property.update!(safety_rating: nil, analyzed_at: Time.current)

    get property_url(property)
    assert_redirected_to edit_property_analyses_checklist_path(property)
  end

  test "GET show renders pre-analysis state when no analysis" do
    property = properties(:unanalyzed_officetel)

    get property_url(property)
    assert_response :success
    assert_select "a", text: "분석 시작"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `eval "$(rbenv init -)" && bin/rails test test/controllers/properties_controller_test.rb`
Expected: 2 FAIL (redirect tests fail, pre-analysis may pass or fail)

- [ ] **Step 3: Update PropertiesController#show**

Replace lines 20-27 in `app/controllers/properties_controller.rb`:

```ruby
  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)

    if @user_property&.safety_rating.present?
      redirect_to property_analyses_rating_path(@property)
    elsif @user_property&.analyzed_at.present?
      redirect_to edit_property_analyses_checklist_path(@property)
    end
  end
```

- [ ] **Step 4: Update properties/show.html.erb for pre-analysis state**

Replace the entire file:

```erb
<%# app/views/properties/show.html.erb %>
<div class="space-y-4">
  <div class="flex items-center gap-2">
    <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>
  </div>

  <%= render CardComponent.new(title: @property.case_number) do |card| %>
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <% if @property.court_name.present? %>
          <span class="text-sm text-slate-500 dark:text-slate-400"><%= @property.court_name %></span>
        <% end %>
      </div>
      <p class="text-sm text-slate-700 dark:text-slate-300"><%= @property.address %></p>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-500 dark:text-slate-400">감정가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_in_eok(@property.appraisal_price) %></p>
        </div>
        <div>
          <span class="text-slate-500 dark:text-slate-400">최저매각가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_in_eok(@property.min_bid_price) %></p>
        </div>
      </div>
      <div class="mt-4 text-center">
        <%= button_to "분석 시작", property_analyses_start_path(@property), method: :post,
            class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `eval "$(rbenv init -)" && bin/rails test test/controllers/properties_controller_test.rb`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
eval "$(rbenv init -)" && git add app/controllers/properties_controller.rb app/views/properties/show.html.erb test/controllers/properties_controller_test.rb && git commit -m "feat: update property show for pre-analysis state with redirects

Post-analysis entry redirects to rating (complete) or checklist (in-progress).
Pre-analysis shows card with '분석 시작' button, no stepper."
```

---

## Task 7: Delete Old Tab Components

**Files:**
- Delete: `app/components/property_tabs_component.rb`
- Delete: `app/components/property_tabs_component.html.erb`
- Delete: `test/components/property_tabs_component_test.rb`
- Delete: `app/javascript/controllers/property_tabs_controller.js`

- [ ] **Step 1: Verify no remaining references to PropertyTabsComponent**

Run: `eval "$(rbenv init -)" && grep -r "PropertyTabsComponent\|property_tabs\|property-tabs" app/ test/ --include="*.rb" --include="*.erb" --include="*.js" -l`

Expected: Only the 4 files being deleted. If other files reference it, update them first.

- [ ] **Step 2: Delete old files**

```bash
eval "$(rbenv init -)" && git rm app/components/property_tabs_component.rb app/components/property_tabs_component.html.erb test/components/property_tabs_component_test.rb app/javascript/controllers/property_tabs_controller.js
```

- [ ] **Step 3: Run full test suite**

Run: `eval "$(rbenv init -)" && bin/rails test`
Expected: All PASS — no references to deleted components remain

- [ ] **Step 4: Commit**

```bash
eval "$(rbenv init -)" && git commit -m "refactor: remove PropertyTabsComponent and property_tabs_controller

Replaced by StepperComponent and stepper_controller"
```

---

## Task 8: Update Integration Test for Stepper Flow

**Files:**
- Modify: `test/integration/property_analysis_flow_test.rb`

- [ ] **Step 1: Update integration test for new entry point behavior**

Replace the entire file:

```ruby
# test/integration/property_analysis_flow_test.rb
require "test_helper"

class PropertyAnalysisFlowTest < ActionDispatch::IntegrationTest
  test "full analysis flow: show → analyze → checklist → rating" do
    get start_onboarding_url
    current_user = User.find_by(email: "guest@auction.local")

    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    current_user.user_properties.find_or_create_by!(property: property)

    # Pre-analysis: show page renders without redirect
    get property_url(property)
    assert_response :success

    # Start analysis → redirects to checklist
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_checklist_url(property)
    follow_redirect!
    assert_response :success

    # Build unified resolutions params
    resolutions = {}

    property.property_check_results.where(source_type: "auto", has_risk: true, user: current_user).each do |r|
      resolutions[r.id] = { resolvable: "false", resolution_note: "해결 불가" }
    end

    property.property_check_results.where(source_type: nil, user: current_user).each do |r|
      resolutions[r.id] = { has_risk: "false" }
    end

    patch property_analyses_checklist_url(property), params: { resolutions: resolutions }
    assert_redirected_to property_analyses_rating_url(property)
    follow_redirect!
    assert_response :success

    # Verify rating was set
    user_property = current_user.user_properties.find_by(property: property)
    assert user_property&.safety_rating.present?

    # Re-entry: show page redirects to rating
    get property_url(property)
    assert_redirected_to property_analyses_rating_path(property)
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `eval "$(rbenv init -)" && bin/rails test test/integration/property_analysis_flow_test.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
eval "$(rbenv init -)" && git add test/integration/property_analysis_flow_test.rb && git commit -m "test: update integration test for stepper workflow

Verifies pre-analysis show, full analysis flow, and re-entry redirect"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `eval "$(rbenv init -)" && bin/rails test`
Expected: All PASS

- [ ] **Step 2: Run Rubocop**

Run: `eval "$(rbenv init -)" && bin/rubocop`
Expected: No offenses (or auto-fix with `bin/rubocop -a`)

- [ ] **Step 3: Run Brakeman security scan**

Run: `eval "$(rbenv init -)" && bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 4: Manual smoke test**

Start the dev server and verify:
1. Visit a property with no analysis → see card + "분석 시작" button, no stepper
2. Click "분석 시작" → redirected to checklist with stepper showing step 1 active
3. Complete checklist → redirected to rating with stepper showing step 3 active
4. Click completed step 1 in stepper → checklist content loads in frame
5. Click pending step (if any) → warning message appears
6. Close and revisit property → redirected to rating page
