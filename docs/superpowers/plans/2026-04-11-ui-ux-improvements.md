# UI/UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 9 UI/UX issues identified from user testing — file upload UX, button consistency, layout, badges, sidebar labels, and responsive grid.

**Architecture:** All changes are frontend-focused (views, components, Stimulus controller) with one model method and one controller update. Changes are independent enough to commit per task.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus (JS), TailwindCSS, Minitest

---

## File Structure

| File | Responsibility |
|------|---------------|
| `app/javascript/controllers/file_upload_controller.js` | **Create** — Stimulus controller: toggle submit button disabled state, render file list |
| `app/models/property.rb` | **Modify** — Add `analyzed?` method |
| `app/components/sidebar/component.rb` | **Modify** — Update menu labels |
| `app/components/property_card_component.rb` | **Modify** — Accept `analyzed` param |
| `app/components/property_card_component.html.erb` | **Modify** — Render AI badge |
| `app/views/analyses/new.html.erb` | **Modify** — File upload UX, button sizing |
| `app/views/properties/show.html.erb` | **Modify** — Unified form, re-analyze/view results |
| `app/views/properties/index.html.erb` | **Modify** — Move search button, width, grid breakpoint |
| `app/views/search_results/_inline_result_item.html.erb` | **Modify** — Price order |
| `app/views/search_results/_inline_results.html.erb` | **Modify** — Grid breakpoint |
| `app/controllers/inspections/start_controller.rb` | **Modify** — Accept documents param |
| `test/models/property_test.rb` | **Modify** — Test `analyzed?` |
| `test/components/property_card_component_test.rb` | **Modify** — Test AI badge |
| `test/components/sidebar/component_test.rb` | **Modify** — Update label assertions |

---

### Task 1: Sidebar Menu Label Changes (Spec §9)

**Files:**
- Modify: `app/components/sidebar/component.rb:7-21`
- Modify: `test/components/sidebar/component_test.rb`

- [ ] **Step 1: Update sidebar test for new labels**

In `test/components/sidebar/component_test.rb`, change the tests that assert on old labels:

```ruby
# In test "renders 3 group titles"
# Change:
assert_text "분석 (P1)"
assert_text "낙찰 후 (P2)"
# To:
assert_text "리포트"
assert_text "가이드"

# In test "renders enabled menu item labels"
# Change:
assert_text "새 분석"
# To:
assert_text "AI분석"

# In test "renders enabled items as links"
# Change:
assert_selector "a[href='/analyses/new']", text: "새 분석"
# To:
assert_selector "a[href='/analyses/new']", text: "AI분석"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/sidebar/component_test.rb`
Expected: FAIL — old labels still in component

- [ ] **Step 3: Update sidebar component labels**

In `app/components/sidebar/component.rb`, update `MENU_GROUPS`:

```ruby
MENU_GROUPS = {
  "물건검색" => [
    MenuItem.new(label: "예산 설정", icon: "calculator", path: "/onboarding", enabled: true),
    MenuItem.new(label: "물건 목록", icon: "magnifying-glass", path: "/properties", enabled: true),
    MenuItem.new(label: "AI분석", icon: "document-plus", path: "/analyses/new", enabled: true)
  ],
  "리포트" => [
    MenuItem.new(label: "순수익 계산기", icon: "banknotes", path: nil, enabled: false),
    MenuItem.new(label: "통합 시세 조회", icon: "chart-bar", path: nil, enabled: false),
    MenuItem.new(label: "리포트 내보내기", icon: "arrow-down-tray", path: nil, enabled: false)
  ],
  "가이드" => [
    MenuItem.new(label: "명도 가이드", icon: "key", path: nil, enabled: false)
  ]
}.freeze
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/sidebar/component_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/sidebar/component.rb test/components/sidebar/component_test.rb
git commit -m "feat: rename sidebar menu labels (AI분석, 리포트, 가이드)"
```

---

### Task 2: Property.analyzed? Method (Spec §3)

**Files:**
- Modify: `app/models/property.rb:1-25`
- Modify or Create: `test/models/property_test.rb`

- [ ] **Step 1: Write failing tests**

Check if `test/models/property_test.rb` exists. If not, create it. Add:

```ruby
# test/models/property_test.rb
require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "analyzed? returns true when inspection_results exist" do
    property = properties(:safe_apartment)
    assert property.analyzed?
  end

  test "analyzed? returns false when no inspection_results exist" do
    property = properties(:unanalyzed_officetel)
    assert_not property.analyzed?
  end
end
```

Note: `safe_apartment` has inspection results in fixtures, `unanalyzed_officetel` does not.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/property_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'analyzed?'`

- [ ] **Step 3: Implement analyzed? method**

In `app/models/property.rb`, add before `private`:

```ruby
def analyzed?
  inspection_results.exists?
end
```

Full file should be:
```ruby
class Property < ApplicationRecord
  has_many :auction_schedules, dependent: :destroy

  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy
  has_many :llm_analysis_logs, dependent: :destroy

  has_many_attached :documents

  validates :case_number, presence: true, uniqueness: true
  validate :documents_must_be_pdf

  def analyzed?
    inspection_results.exists?
  end

  private

  def documents_must_be_pdf
    documents.each do |doc|
      unless doc.content_type == "application/pdf"
        errors.add(:documents, "PDF 파일만 업로드할 수 있습니다.")
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/property_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/property.rb test/models/property_test.rb
git commit -m "feat: add Property#analyzed? method"
```

---

### Task 3: Property Card — AI Analysis Badge (Spec §4)

**Files:**
- Modify: `app/components/property_card_component.rb:1-22`
- Modify: `app/components/property_card_component.html.erb:18-23`
- Modify: `test/components/property_card_component_test.rb`
- Modify: `app/views/properties/index.html.erb:121-125`

- [ ] **Step 1: Write failing tests**

Add to `test/components/property_card_component_test.rb`:

```ruby
test "renders AI analysis badge when analyzed is true" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property, analyzed: true))
  assert_selector ".inline-flex", text: "AI 분석완료"
end

test "does not render AI analysis badge when analyzed is false" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property, analyzed: false))
  assert_no_text "AI 분석완료"
end

test "does not render AI analysis badge when analyzed is not provided" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property))
  assert_no_text "AI 분석완료"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: FAIL — `ArgumentError: unknown keyword: :analyzed`

- [ ] **Step 3: Update PropertyCardComponent to accept analyzed param**

In `app/components/property_card_component.rb`:

```ruby
class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, safety_rating: nil, max_bid_amount: nil, analyzed: false)
    @property = property
    @safety_rating = safety_rating
    @max_bid_amount = max_bid_amount
    @analyzed = analyzed
  end

  private

  def formatted_price(amount)
    helpers.format_price_won(amount)
  end

  def budget_exceeded?
    return false unless @max_bid_amount.present? && @property.appraisal_price.present?

    @property.appraisal_price > @max_bid_amount * 10000
  end
end
```

- [ ] **Step 4: Add badge to template**

In `app/components/property_card_component.html.erb`, find the badge row (line 18-23):

```erb
      <div class="mt-1 flex items-center gap-1.5 flex-wrap">
        <%= render SafetyBadgeComponent.new(rating: @safety_rating) %>
        <% if budget_exceeded? %>
          <%= render(BadgeComponent.new(variant: :warning)) { "예산 초과" } %>
        <% end %>
      </div>
```

Replace with:

```erb
      <div class="mt-1 flex items-center gap-1.5 flex-wrap">
        <%= render SafetyBadgeComponent.new(rating: @safety_rating) %>
        <% if @analyzed %>
          <%= render(BadgeComponent.new(variant: :accent)) { "AI 분석완료" } %>
        <% end %>
        <% if budget_exceeded? %>
          <%= render(BadgeComponent.new(variant: :warning)) { "예산 초과" } %>
        <% end %>
      </div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/components/property_card_component_test.rb`
Expected: All PASS

- [ ] **Step 6: Update property index to pass analyzed param**

In `app/views/properties/index.html.erb`, find the card rendering (line 121-125):

```erb
        <%= render PropertyCardComponent.new(
          property: user_property.property,
          safety_rating: user_property.safety_rating,
          max_bid_amount: @max_bid_amount
        ) %>
```

Replace with:

```erb
        <%= render PropertyCardComponent.new(
          property: user_property.property,
          safety_rating: user_property.safety_rating,
          max_bid_amount: @max_bid_amount,
          analyzed: user_property.property.analyzed?
        ) %>
```

- [ ] **Step 7: Commit**

```bash
git add app/components/property_card_component.rb app/components/property_card_component.html.erb test/components/property_card_component_test.rb app/views/properties/index.html.erb
git commit -m "feat: add AI analysis badge to property cards"
```

---

### Task 4: File Upload Stimulus Controller (Spec §1, §2, §8)

**Files:**
- Create: `app/javascript/controllers/file_upload_controller.js`

- [ ] **Step 1: Create file upload Stimulus controller**

```javascript
// app/javascript/controllers/file_upload_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit", "fileList"]

  connect() {
    this.updateState()
  }

  select() {
    const files = this.inputTarget.files
    this.renderFileList(files)
    this.updateState()
  }

  updateState() {
    const hasFiles = this.inputTarget.files.length > 0
    this.submitTarget.disabled = !hasFiles

    if (hasFiles) {
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
    } else {
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  renderFileList(files) {
    if (!this.hasFileListTarget) return

    if (files.length === 0) {
      this.fileListTarget.classList.add("hidden")
      this.fileListTarget.innerHTML = ""
      return
    }

    this.fileListTarget.classList.remove("hidden")
    const items = Array.from(files).map(f =>
      `<li class="flex items-center gap-1.5">
        <svg class="w-4 h-4 text-slate-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"/>
        </svg>
        <span class="truncate">${f.name}</span>
        <span class="text-slate-500 flex-shrink-0">(${this.formatSize(f.size)})</span>
      </li>`
    ).join("")

    this.fileListTarget.innerHTML = `<ul class="space-y-1">${items}</ul>`
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)}KB`
    return `${(bytes / 1048576).toFixed(1)}MB`
  }
}
```

- [ ] **Step 2: Verify controller is auto-registered**

Stimulus controllers in `app/javascript/controllers/` are auto-registered by Rails importmap + stimulus-loading. No manual registration needed. Confirm by checking:

Run: `grep -r "stimulus-loading" app/javascript/`
Expected: `eagerLoadControllersFrom` in `app/javascript/controllers/index.js`

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/file_upload_controller.js
git commit -m "feat: add file-upload Stimulus controller for file selection UX"
```

---

### Task 5: New Analysis Page — File Upload UX (Spec §1, §8)

**Files:**
- Modify: `app/views/analyses/new.html.erb`

- [ ] **Step 1: Rewrite the form in new.html.erb**

Replace the entire file content with:

```erb
<div class="max-w-lg mx-auto space-y-4">
  <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">새 분석</h1>

  <%= render CardComponent.new(title: "PDF 문서 업로드") do %>
    <div class="space-y-3">
      <p class="text-sm text-slate-600 dark:text-slate-400">
        법원경매 사이트에서 확보한 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본 등)를 PDF로 업로드해주세요.
      </p>
      <div class="text-xs text-amber-600 dark:text-amber-400">
        업로드된 문서는 AI 분석을 위해 외부 API(선택한 LLM 제공자)로 전송됩니다.
      </div>

      <div id="analysis_form" data-controller="file-upload">
        <%= form_with url: analyses_path, method: :post, class: "space-y-3" do |f| %>
          <div>
            <%= f.file_field :documents, multiple: true, accept: "application/pdf",
                data: { file_upload_target: "input", action: "change->file-upload#select" },
                class: "block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:file:bg-blue-900 dark:file:text-blue-300 dark:text-slate-400" %>
          </div>
          <div data-file-upload-target="fileList" class="hidden text-sm text-slate-600 dark:text-slate-400 bg-slate-50 dark:bg-slate-800 rounded-md p-3 border border-slate-200 dark:border-slate-700"></div>
          <%= f.submit "분석 시작",
              data: { file_upload_target: "submit" },
              disabled: true,
              class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed" %>
        <% end %>
      </div>
    </div>
  <% end %>

  <div id="analysis_progress">
    <%= turbo_stream_from "analysis_progress_#{current_user.id}" %>
  </div>
</div>
```

Key changes:
- Added `data-controller="file-upload"` wrapper
- File input has `data-file_upload_target="input"` and `data-action="change->file-upload#select"`
- Submit button starts `disabled: true` with `data-file_upload_target="submit"`
- Added `fileList` target div for displaying selected files
- Submit button has `disabled:opacity-50 disabled:cursor-not-allowed` classes
- File input has `dark:text-slate-400` for better visibility in dark mode

- [ ] **Step 2: Manually verify in browser**

Run: `bin/dev`
Visit: `http://localhost:3000/analyses/new`
Verify:
1. "분석 시작" button is disabled and looks disabled (opacity)
2. After selecting files, button becomes enabled
3. Selected file names appear in a list below file input
4. "파일 선택" button text is visible (not grayed out)

- [ ] **Step 3: Commit**

```bash
git add app/views/analyses/new.html.erb
git commit -m "feat: improve file upload UX on new analysis page"
```

---

### Task 6: Property Show — Unified Form + Re-analyze (Spec §2, §3)

**Files:**
- Modify: `app/controllers/inspections/start_controller.rb:1-19`
- Modify: `app/views/properties/show.html.erb:1-47`

- [ ] **Step 1: Update StartController to accept documents**

Replace `app/controllers/inspections/start_controller.rb`:

```ruby
module Inspections
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])

      if params[:documents].present?
        @property.documents.attach(params[:documents])
      end

      unless @property.documents.attached?
        redirect_to property_path(@property), alert: "분석할 문서를 먼저 업로드해주세요."
        return
      end

      PdfAnalysisJob.perform_later(
        property_id: @property.id,
        user_id: current_user.id
      )

      redirect_to property_path(@property), notice: "분석이 시작되었습니다."
    end
  end
end
```

- [ ] **Step 2: Rewrite property show page**

Replace `app/views/properties/show.html.erb`:

```erb
<%# app/views/properties/show.html.erb %>
<div class="max-w-lg mx-auto space-y-4">
  <div class="flex items-center gap-2">
    <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>
  </div>

  <%= render CardComponent.new(title: @property.case_number) do |card| %>
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <% if @property.building_name.present? %>
          <span class="text-sm text-slate-500 dark:text-slate-400"><%= @property.building_name %></span>
        <% end %>
      </div>
      <p class="text-sm text-slate-700 dark:text-slate-300"><%= @property.address %></p>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-500 dark:text-slate-400">감정가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_won(@property.appraisal_price) %></p>
        </div>
        <div>
          <span class="text-slate-500 dark:text-slate-400">최저매각가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_price_won(@property.min_bid_price) %></p>
        </div>
      </div>
    </div>
  <% end %>

  <%= render CardComponent.new(title: "문서") do %>
    <div class="space-y-4">
      <%= render "properties/documents/list", property: @property %>

      <div data-controller="file-upload">
        <%= form_with url: property_inspections_start_path(@property), method: :post, class: "space-y-3" do |f| %>
          <div class="text-xs text-amber-600 dark:text-amber-400">
            업로드된 문서는 AI 분석을 위해 외부 API(선택한 LLM 제공자)로 전송됩니다.
          </div>
          <div>
            <%= f.file_field :documents, multiple: true, accept: "application/pdf",
                data: { file_upload_target: "input", action: "change->file-upload#select" },
                class: "block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:file:bg-blue-900 dark:file:text-blue-300 dark:text-slate-400" %>
          </div>
          <div data-file-upload-target="fileList" class="hidden text-sm text-slate-600 dark:text-slate-400 bg-slate-50 dark:bg-slate-800 rounded-md p-3 border border-slate-200 dark:border-slate-700"></div>

          <% if @property.analyzed? %>
            <div class="flex items-center gap-2">
              <%= link_to edit_property_inspections_tab_path(@property, tab_key: "rights_analysis"),
                  class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" do %>
                분석 결과 보기
              <% end %>
              <%= f.submit "다시 분석",
                  data: { file_upload_target: "submit" },
                  class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
            </div>
          <% elsif @property.documents.attached? %>
            <%= f.submit "분석 시작",
                data: { file_upload_target: "submit" },
                class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
          <% else %>
            <%= f.submit "분석 시작",
                data: { file_upload_target: "submit" },
                disabled: true,
                class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed" %>
          <% end %>
        <% end %>
      </div>
    </div>
  <% end %>

  <div id="analysis_progress">
    <%= turbo_stream_from "analysis_progress_#{current_user.id}" %>
  </div>
</div>
```

Key changes:
- Removed `render "properties/documents/form"` — file input is now inline
- Single form POSTs to `property_inspections_start_path` (handles both upload + analysis)
- Uses `file-upload` Stimulus controller for file list and button state
- Three states: analyzed (결과 보기 + 다시 분석), documents attached (분석 시작), no documents (분석 시작 disabled)
- "다시 분석" is always enabled (existing docs can be re-analyzed)
- Removed standalone "문서를 업로드하면 분석을 시작할 수 있습니다." text — the disabled button conveys this

- [ ] **Step 3: Manually verify in browser**

Visit: `http://localhost:3000/properties/:id` (a property with no documents)
Verify:
1. File picker visible, no "업로드" button
2. "분석 시작" button disabled until files are selected
3. Selected files display as a list

Visit: a property with existing analysis (inspection_results)
Verify:
1. "분석 결과 보기" link appears, links to rights_analysis tab
2. "다시 분석" button appears

- [ ] **Step 4: Commit**

```bash
git add app/controllers/inspections/start_controller.rb app/views/properties/show.html.erb
git commit -m "feat: unify document upload and analysis start on property show"
```

---

### Task 7: Criteria Search Button Relocation + Add Button Text (Spec §5)

**Files:**
- Modify: `app/views/properties/index.html.erb:22-69`

- [ ] **Step 1: Rewrite the criteria search section**

In `app/views/properties/index.html.erb`, replace from line 22 (`<%# Case number input + criteria search %>`) through line 69 (`<p class="text-sm...법원을 선택하면...`):

```erb
  <%# Case number input + criteria search %>
  <div data-controller="criteria-search">
    <div class="mb-4">
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">관심 지역</label>
      <div class="flex items-center gap-2">
        <select name="budget_setting[region]"
                class="flex-1 h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
                data-controller="region-select"
                data-region-select-url-value="<%= update_region_settings_budget_path %>"
                data-action="change->region-select#save">
          <% BudgetSetting::REGIONS.each do |region| %>
            <option value="<%= region %>" <%= "selected" if region == @setting&.effective_region %>><%= region %></option>
          <% end %>
        </select>
        <span class="text-sm text-slate-500 dark:text-slate-400 transition-opacity duration-300 opacity-0" data-region-select-target="feedback"></span>
        <%= form_with url: search_results_path, method: :post, class: "contents", data: { turbo_stream: true, action: "submit->criteria-search#submit turbo:submit-end->criteria-search#enable" } do %>
          <button type="submit"
                  data-criteria-search-target="submitButton"
                  class="inline-flex items-center justify-center gap-1.5 px-5 h-10 rounded-md bg-violet-600 hover:bg-violet-700 dark:bg-violet-600 dark:hover:bg-violet-500 text-white text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-violet-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-slate-900">
            <span data-criteria-search-target="buttonText">조건검색</span>
            <svg data-criteria-search-target="buttonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </button>
        <% end %>
      </div>
    </div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
    <div class="flex items-center gap-2">
      <%= form_with url: properties_path, method: :post, class: "contents", data: { action: "submit->criteria-search#submitCaseNumber" } do |f| %>
        <%= f.text_field :case_number,
            placeholder: "예: 2026타경1234",
            data: { criteria_search_target: "caseInput" },
            class: "flex-1 min-w-0 h-10 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
        <button type="submit" data-criteria-search-target="addButton"
                class="inline-flex items-center justify-center gap-1.5 h-10 px-4 text-sm font-medium rounded-md bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400 text-white transition-colors">
          <span data-criteria-search-target="addButtonText" class="flex items-center gap-1">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.5v15m7.5-7.5h-15"/></svg>
            추가
          </span>
          <svg data-criteria-search-target="addButtonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </button>
      <% end %>
    </div>
    <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원을 선택하면 빠르게 검색됩니다</p>
  </div>
```

Key changes:
- Removed `class="max-w-2xl"` from the container
- Moved criteria search form/button into the region select row
- Changed all input heights from `h-8` to `h-10` for consistency
- Added "추가" text next to the "+" icon in the add button
- Criteria search button height changed to `h-10` to match

- [ ] **Step 2: Manually verify in browser**

Visit: `http://localhost:3000/properties`
Verify:
1. "조건검색" button is next to the region dropdown
2. "+" button now shows "+ 추가" text
3. Region/case-number area spans same width as the filter bar below
4. All input heights are consistent

- [ ] **Step 3: Commit**

```bash
git add app/views/properties/index.html.erb
git commit -m "feat: relocate criteria search button and add text to add button"
```

---

### Task 8: Search Result Card — Price Order (Spec §6)

**Files:**
- Modify: `app/views/search_results/_inline_result_item.html.erb`

- [ ] **Step 1: Rewrite search result card layout**

Replace `app/views/search_results/_inline_result_item.html.erb`:

```erb
<%# app/views/search_results/_inline_result_item.html.erb %>
<div id="<%= dom_id(search_result, :inline) %>"
     class="bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl p-3 cursor-pointer hover:border-violet-500 dark:hover:border-violet-500 transition-colors">
  <%= form_with url: inline_import_search_result_path(search_result), method: :post, data: { turbo_stream: true, turbo_frame: "_top" } do %>
    <button type="submit" class="w-full text-left cursor-pointer">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-violet-400">
          <%= search_result.case_number %>
          <% if search_result.property_count > 1 %>
            <span class="inline-flex items-center rounded bg-amber-900/30 px-1.5 py-0.5 text-xs font-medium text-amber-400">다물건 <%= search_result.property_count %>건</span>
          <% end %>
        </span>
      </div>
      <div class="mt-1.5 space-y-0.5">
        <div class="text-xs text-slate-500">감정가 <span class="text-slate-300 font-medium"><%= format_price_won(search_result.appraisal_price) %></span></div>
        <div class="text-xs text-slate-500">최저매각가 <span class="text-slate-300 font-medium"><%= format_price_won(search_result.min_bid_price) %></span></div>
      </div>
      <div class="text-xs text-slate-500 mt-1 truncate">📍 <%= search_result.address %></div>
    </button>
  <% end %>
</div>
```

Key changes:
- Moved 감정가 out of the header row into its own line below case number
- 감정가 first, then 최저매각가 — consistent order with property cards
- Both prices on separate lines with consistent formatting

- [ ] **Step 2: Manually verify in browser**

Visit: `http://localhost:3000/properties`, click 조건검색
Verify: Each search result card shows 감정가 above 최저매각가

- [ ] **Step 3: Commit**

```bash
git add app/views/search_results/_inline_result_item.html.erb
git commit -m "feat: reorder prices in search result cards (감정가 above 최저매각가)"
```

---

### Task 9: Responsive Grid Breakpoints (Spec §7)

**Files:**
- Modify: `app/views/properties/index.html.erb:119`
- Modify: `app/views/search_results/_inline_results.html.erb:14`

- [ ] **Step 1: Update property cards grid**

In `app/views/properties/index.html.erb`, find:

```erb
    <div id="property-cards-grid" class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
```

Replace with:

```erb
    <div id="property-cards-grid" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
```

- [ ] **Step 2: Update search results grid**

In `app/views/search_results/_inline_results.html.erb`, find:

```erb
    <div class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
```

Replace with:

```erb
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
```

- [ ] **Step 3: Manually verify in browser**

Resize browser window and verify:
- < 640px: 1 column
- 640-1023px: 2 columns
- 1024-1279px: 3 columns
- 1280px+: 4 columns

- [ ] **Step 4: Commit**

```bash
git add app/views/properties/index.html.erb app/views/search_results/_inline_results.html.erb
git commit -m "feat: adjust responsive grid breakpoints (4-col at xl only)"
```

---

### Task 10: Run Full Test Suite

- [ ] **Step 1: Run all tests**

Run: `bin/rails test`
Expected: All pass, no regressions

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Fix any issues found**

If tests or rubocop fail, fix and commit each fix separately.
