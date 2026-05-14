# Property Detail Page — Stepper Workflow Redesign

## 1. Overview

### Problem

The current tab-based navigation on the property detail page has critical UX issues:

1. **Active tab not updating** — Clicking any tab always shows "기본 정보" as active because the Stepper lives outside the Turbo Frame, but analysis views don't re-render it.
2. **No sequential flow indication** — Tabs imply free navigation, but the analysis process is inherently sequential (checklist → rights analysis → rating).
3. **Confusing entry point** — Users don't understand what to do first or how the tabs relate to each other.

### Solution

Replace the tab navigation with a **Chevron Stepper** that explicitly communicates a sequential workflow: checklist → rights analysis → rating. The property detail card stays fixed above the stepper, and the "기본 정보" tab is removed (its content is always visible in the card).

### Scope

- Replace `PropertyTabsComponent` with `StepperComponent`
- Restructure `properties/show.html.erb` layout
- Update all analysis views for Turbo Frame consistency
- Add Stimulus controller for stepper interaction
- Update `PropertiesController#show` entry point logic

---

## 2. Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Navigation style | Chevron Stepper (sequential) over free-form tabs | Analysis is inherently sequential; tabs gave false impression of free navigation |
| Number of steps | 3 (removed "기본 정보") | Property card is always visible above stepper; dedicated tab is redundant |
| Incomplete step click | Show warning message | Allows exploration without blocking, communicates prerequisite clearly |
| Re-entry after completion | Land on last step (등급 산정) | Users revisit to see final result; can navigate back to earlier steps |
| Stepper placement | Outside Turbo Frame | Stepper persists during content swaps; active state managed by Stimulus |

---

## 3. Page Structure

```
┌─────────────────────────────────────────────────┐
│ ← 목록                                          │
├─────────────────────────────────────────────────┤
│ Property Detail Card (always visible)            │
│ - Case number, badge, court, address             │
│ - Appraisal price, min bid price                 │
│ - Pre-analysis: "분석 시작" button inside card   │
├─────────────────────────────────────────────────┤
│ StepperComponent (visible only after analysis)   │
│ ┌──────────┬──────────────┬──────────────┐      │
│ │체크리스트 ▸│ 권리 분석   ▸│ 등급 산정    │      │
│ └──────────┴──────────────┴──────────────┘      │
├─────────────────────────────────────────────────┤
│ turbo_frame "tab_content"                        │
│ (step-specific content)                          │
└─────────────────────────────────────────────────┘
```

---

## 4. States

### 4-1. Pre-Analysis

- Property detail card with full information (case number, address, prices)
- "분석 시작" button centered below card content
- Stepper is **not visible**
- No Turbo Frame content

### 4-2. Analysis In Progress

- Property detail card **collapsed** to single line (case number + badge + price)
- Chevron Stepper visible with 3 steps
- Current step highlighted (blue background, white text)
- Completed steps show ✓ with muted blue background
- Pending steps show gray background
- Turbo Frame shows current step's content

### 4-3. All Steps Complete (Re-visit)

- Same collapsed card
- All stepper steps show ✓
- Last step (등급 산정) is active (highlighted)
- All steps are clickable for review
- "다시 분석하기" button in rating content

---

## 5. Chevron Stepper Visual Design

### Step States

| State | Background | Text | Icon | Clickable |
|---|---|---|---|---|
| Completed | `bg-blue-900/50` (#1e3a5f) | `text-blue-300` (#93c5fd) | ✓ | Yes — navigates to that step's content |
| Active | `bg-blue-600` (#2563eb) | `text-white` | Step number | N/A (current) |
| Pending | `bg-slate-800` (#1e293b) | `text-slate-500` (#64748b) | Step number | Yes — shows warning message |

### Chevron Shape

Each step uses CSS `clip-path` to create a chevron (arrow) shape:
- First step: flat left edge, pointed right edge
- Middle steps: notched left edge, pointed right edge
- Last step: notched left edge, flat right edge

### Dark Mode Only

The app uses dark mode exclusively. No light mode variants needed.

---

## 6. Components

### 6-1. StepperComponent (new)

Replaces `PropertyTabsComponent`.

```ruby
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
end
```

**Parameters:**
- `property` — the Property record
- `user` — current user
- `active_step` — one of `:checklist`, `:report`, `:rating`

**Step state logic:**
- `:completed` — step's prerequisite data exists (same logic as current `tab_completed?`)
- `:active` — matches `active_step` parameter
- `:pending` — not completed and not active

**Step URLs:**
- `:checklist` → `edit_property_analyses_checklist_path`
- `:report` → `property_analyses_report_path`
- `:rating` → `property_analyses_rating_path`

**Rendered HTML:** Each step is a link with `data-turbo-frame="tab_content"` and stepper Stimulus controller data attributes for click interception on pending steps.

### 6-2. PropertyTabsComponent (delete)

Remove entirely. All references in views replaced by `StepperComponent`.

---

## 7. Controller Changes

### 7-1. PropertiesController#show

Entry point logic determines what the user sees:

```ruby
def show
  @property = Property.find(params[:id])
  @user_property = current_user.user_properties.find_by(property: @property)

  if @user_property&.safety_rating.present?
    redirect_to property_analyses_rating_path(@property)
  elsif @user_property&.analyzed_at.present?
    redirect_to edit_property_analyses_checklist_path(@property)
  end
  # else: render show (pre-analysis state)
end
```

### 7-2. Analysis Controllers

Each analysis controller sets `@active_step` for the stepper:

- `Analyses::ChecklistsController#edit` → `@active_step = :checklist`
- `Analyses::ReportsController#show` → `@active_step = :report`
- `Analyses::RatingsController#show` → `@active_step = :rating`

---

## 8. View Changes

### 8-1. properties/show.html.erb

Restructured to show only the pre-analysis state:

- Property detail card with full info
- "분석 시작" button
- No stepper, no Turbo Frame (redirects handle post-analysis)

### 8-2. Analysis Views (checklists/edit, reports/show, ratings/show)

Each view renders as a **full page** (not just Turbo Frame content) that includes:

1. Property detail card (collapsed, single line)
2. StepperComponent with correct `active_step`
3. `turbo_frame_tag "tab_content"` wrapping the step-specific content

**Turbo Frame vs full page load:** Stepper links use `data-turbo-frame="tab_content"`, so clicking a completed step replaces only the frame content. However, the stepper itself is outside the frame, so the Stimulus controller must update the active step visually on click (without server round-trip). On full page load (direct URL or redirect), the server renders the correct `active_step` from the controller.

### 8-3. Shared Layout Partial

Extract the common structure (collapsed card + stepper + frame) into a shared partial to avoid duplication:

```erb
<%# app/views/analyses/_layout.html.erb %>
<div class="space-y-3">
  <%= render "analyses/property_card_compact", property: @property, user_property: @user_property %>
  <%= render StepperComponent.new(property: @property, user: current_user, active_step: active_step) %>
  <%= turbo_frame_tag "tab_content" do %>
    <%= yield %>
  <% end %>
</div>
```

---

## 9. Stimulus Controller

### stepper_controller.js

Handles client-side stepper interactions:

**Responsibilities:**
- Intercept clicks on pending steps
- Show inline warning message ("이전 단계를 먼저 완료해주세요")
- Allow clicks on completed steps (normal Turbo Frame navigation)
- Update visual active state after Turbo Frame loads

**Data attributes on each step link:**
- `data-stepper-target="step"`
- `data-step-status="completed|active|pending"`
- `data-step-key="checklist|report|rating"`

**Warning message behavior:**
- Displayed inside the Turbo Frame content area
- Shows which step must be completed first
- Warning border color: `border-amber-700`, text: `text-amber-500`
- Dismissed automatically when user clicks a valid step

---

## 10. Incomplete Step Warning

When a user clicks a pending step:

```
┌──────────────────────────────────────────────┐
│ ⚠ 이전 단계를 먼저 완료해주세요                  │
│ "권리 분석" 단계를 완료한 후 진행할 수 있습니다.   │
└──────────────────────────────────────────────┘
```

- Border: `border-amber-700` (#b45309)
- Title: `text-amber-500` (#f59e0b), font-weight 500
- Description: `text-slate-400` (#94a3b8)
- Background: `bg-slate-800` (#1e293b)

---

## 11. Testing Strategy

- **Component test:** StepperComponent renders correct states (completed/active/pending) based on data
- **Controller test:** PropertiesController#show redirects correctly based on analysis state
- **Integration test:** Full stepper workflow — click through steps, verify navigation
- **Stimulus test:** Pending step click shows warning, completed step click navigates
