# Background Analysis Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple AI analysis progress from page-level UI so users can navigate freely while analysis runs in the background, receiving toast notifications on completion.

**Architecture:** Extend the existing Turbo Stream broadcast infrastructure with a global user-scoped channel (`user_notifications_#{user.id}`) subscribed in the layout. Controllers provide immediate "started" feedback; `PdfAnalysisJob` broadcasts only terminal states (completed/failed) as global toasts + header indicator updates.

**Tech Stack:** Rails 8.1, Turbo Streams (broadcast), ViewComponent, Stimulus, Solid Queue

**Spec:** `docs/superpowers/specs/2026-04-12-background-analysis-notification-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `app/components/toast_component.rb` | Modify | Add `action_url`/`action_label` params, auto-dismiss logic |
| `app/components/toast_component.html.erb` | Modify | Render optional action link |
| `test/components/toast_component_test.rb` | Modify | Tests for link rendering and duration override |
| `app/components/header/component.html.erb` | Modify | Add `#analysis_indicator` span |
| `test/components/header/component_test.rb` | Modify | Test indicator element presence |
| `app/views/layouts/application.html.erb` | Modify | Add global Turbo Stream subscription + `#global_toasts` container |
| `app/views/notifications/_toast.html.erb` | Create | Broadcast toast partial (renders ToastComponent) |
| `app/views/notifications/_analysis_indicator.html.erb` | Create | Header indicator partial (spinning or empty) |
| `app/jobs/pdf_analysis_job.rb` | Modify | Change broadcast to global channel, terminal states only |
| `test/jobs/pdf_analysis_job_test.rb` | Modify | Update broadcast assertions |
| `app/controllers/analyses_controller.rb` | Modify | Multi-action Turbo Stream response (form reset + toast + indicator) |
| `test/controllers/analyses_controller_test.rb` | Modify | Update response assertions |
| `app/controllers/inspections/start_controller.rb` | Modify | Broadcast indicator on redirect |
| `test/controllers/inspections/start_controller_test.rb` | Modify | Update broadcast assertion |
| `app/views/analyses/new.html.erb` | Modify | Remove page-level subscription and progress div |
| `app/views/properties/show.html.erb` | Modify | Remove page-level subscription and progress div |
| `app/views/analyses/_progress.html.erb` | Delete | Replaced by global toast system |

---

## Task 1: Extend ToastComponent with Action Link

**Files:**
- Modify: `app/components/toast_component.rb`
- Modify: `app/components/toast_component.html.erb`
- Modify: `test/components/toast_component_test.rb`

- [ ] **Step 1: Write failing tests for action link rendering**

Add to `test/components/toast_component_test.rb`:

```ruby
# --- Action link ---

test "renders action link when action_url and action_label provided" do
  render_inline(ToastComponent.new(
    message: "분석 완료",
    type: :success,
    action_url: "/properties/1/inspections/tabs/rights_analysis/edit",
    action_label: "결과 보기"
  ))

  assert_link "결과 보기", href: "/properties/1/inspections/tabs/rights_analysis/edit"
end

test "does not render action link when action_url is nil" do
  render_inline(ToastComponent.new(message: "일반 메시지"))

  assert_no_selector "a"
end

test "disables auto-dismiss when action_url is present" do
  render_inline(ToastComponent.new(
    message: "분석 완료",
    type: :success,
    action_url: "/results",
    action_label: "보기"
  ))

  assert_selector "[data-toast-duration-value='0']"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/toast_component_test.rb`

Expected: 3 failures — `action_url` parameter not recognized, no link rendered, duration still 5000.

- [ ] **Step 3: Implement ToastComponent changes**

Replace `app/components/toast_component.rb` `initialize` method:

```ruby
def initialize(message:, type: :info, duration: 5000, action_url: nil, action_label: nil)
  @message = message
  @type = type.to_sym
  @duration = action_url ? 0 : duration
  @action_url = action_url
  @action_label = action_label
end
```

Replace `app/components/toast_component.html.erb` with:

```erb
<div class="<%= CONTAINER_CLASSES %>" data-controller="toast" data-toast-duration-value="<%= @duration %>">
  <%= icon_html %>
  <div class="flex-1">
    <p class="text-sm text-slate-700 dark:text-slate-300">
      <%= @message %>
      <% if @action_url && @action_label %>
        — <%= link_to @action_label, @action_url, class: "underline font-medium hover:text-slate-900 dark:hover:text-slate-100" %>
      <% end %>
    </p>
  </div>
  <button type="button" data-action="toast#dismiss" class="shrink-0 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200">
    <%= close_icon_html %>
  </button>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/toast_component_test.rb`

Expected: All tests pass (including existing ones — backward compatible).

- [ ] **Step 5: Commit**

```bash
git add app/components/toast_component.rb app/components/toast_component.html.erb test/components/toast_component_test.rb
git commit -m "feat(toast): add optional action link with auto-dismiss override"
```

---

## Task 2: Add Analysis Indicator to Header Component

**Files:**
- Modify: `app/components/header/component.html.erb`
- Modify: `test/components/header/component_test.rb`

- [ ] **Step 1: Write failing test for analysis indicator**

Add to `test/components/header/component_test.rb`:

```ruby
# --- Analysis indicator ---

test "renders analysis indicator placeholder" do
  render_inline(Header::Component.new)

  assert_selector "span#analysis_indicator"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: FAIL — no element matching `span#analysis_indicator`.

- [ ] **Step 3: Add indicator span to header template**

In `app/components/header/component.html.erb`, add the `analysis_indicator` span before the bell button. Replace the right-side buttons section:

```erb
  <div class="flex items-center gap-1">
    <div data-controller="dark-mode">
      <button type="button" class="<%= BUTTON_CLASSES %>" data-action="dark-mode#toggle">
        <span data-dark-mode-target="sunIcon"><%= sun_icon %></span>
        <span data-dark-mode-target="moonIcon" class="hidden"><%= moon_icon %></span>
      </button>
    </div>

    <span id="analysis_indicator"></span>

    <button type="button" class="<%= BUTTON_CLASSES %>">
      <%= bell_icon %>
    </button>

    <button type="button" class="<%= BUTTON_CLASSES %>">
      <%= user_icon %>
    </button>
  </div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/components/header/component.html.erb test/components/header/component_test.rb
git commit -m "feat(header): add analysis indicator placeholder"
```

---

## Task 3: Create Notification Partials

**Files:**
- Create: `app/views/notifications/_toast.html.erb`
- Create: `app/views/notifications/_analysis_indicator.html.erb`

- [ ] **Step 1: Create toast notification partial**

Create `app/views/notifications/_toast.html.erb`:

```erb
<%= render ToastComponent.new(
  message: message,
  type: type.to_sym,
  action_url: defined?(action_url) ? action_url : nil,
  action_label: defined?(action_label) ? action_label : nil
) %>
```

- [ ] **Step 2: Create analysis indicator partial**

Create `app/views/notifications/_analysis_indicator.html.erb`:

```erb
<span id="analysis_indicator">
  <% if defined?(active) && active %>
    <span class="p-2 inline-flex items-center text-blue-400" title="AI 분석 진행 중">
      <svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <span class="sr-only">AI 분석 진행 중</span>
    </span>
  <% end %>
</span>
```

- [ ] **Step 3: Commit**

```bash
mkdir -p app/views/notifications
git add app/views/notifications/_toast.html.erb app/views/notifications/_analysis_indicator.html.erb
git commit -m "feat: add notification partials for toast and analysis indicator"
```

---

## Task 4: Add Global Turbo Stream Subscription to Layout

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Add global subscription and toast container**

In `app/views/layouts/application.html.erb`, add the Turbo Stream subscription inside `<body>` (after the sidebar backdrop div, before the main content div), and add the `#global_toasts` container inside the existing fixed toast area.

Replace the flash toast section and add the subscription. Find this block:

```erb
    <div class="fixed inset-0 z-20 bg-black/50 hidden md:hidden" data-sidebar-target="backdrop" data-action="click->sidebar#close"></div>

    <div class="min-h-screen pt-16 transition-[margin] duration-200 md:ml-16 lg:ml-64" data-sidebar-target="content">
      <% if flash.any? %>
        <div class="fixed top-20 right-4 z-50 flex flex-col gap-2 pointer-events-none">
          <% flash.each do |type, message| %>
            <% toast_type = { "notice" => :success, "alert" => :danger }.fetch(type.to_s, :info) %>
            <%= render ToastComponent.new(message: message, type: toast_type) %>
          <% end %>
        </div>
      <% end %>
```

Replace with:

```erb
    <div class="fixed inset-0 z-20 bg-black/50 hidden md:hidden" data-sidebar-target="backdrop" data-action="click->sidebar#close"></div>

    <% if current_user %>
      <%= turbo_stream_from "user_notifications_#{current_user.id}" %>
    <% end %>

    <div class="min-h-screen pt-16 transition-[margin] duration-200 md:ml-16 lg:ml-64" data-sidebar-target="content">
      <div class="fixed top-20 right-4 z-50 flex flex-col gap-2 pointer-events-none" id="global_toasts">
        <% if flash.any? %>
          <% flash.each do |type, message| %>
            <% toast_type = { "notice" => :success, "alert" => :danger }.fetch(type.to_s, :info) %>
            <%= render ToastComponent.new(message: message, type: toast_type) %>
          <% end %>
        <% end %>
      </div>
```

- [ ] **Step 2: Verify the app renders correctly**

Run: `bin/rails test test/controllers/analyses_controller_test.rb`

Expected: Existing tests still pass (layout change is additive).

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat(layout): add global Turbo Stream subscription and toast container"
```

---

## Task 5: Update PdfAnalysisJob Broadcasts

**Files:**
- Modify: `app/jobs/pdf_analysis_job.rb`
- Modify: `test/jobs/pdf_analysis_job_test.rb`

- [ ] **Step 1: Write failing test for new broadcast behavior**

Replace the broadcast test in `test/jobs/pdf_analysis_job_test.rb`:

```ruby
test "broadcasts completion toast to user notifications channel" do
  # Capture broadcasts to the user's notification channel
  assert_broadcasts("user_notifications_#{@user.id}", 2) do
    PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
  end
end

test "broadcasts failure toast on exception" do
  assert_broadcasts("user_notifications_#{users(:guest).id}", 2) do
    PdfAnalysisJob.perform_now(property_id: -1, user_id: users(:guest).id)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/jobs/pdf_analysis_job_test.rb`

Expected: FAIL — broadcasts go to old channel `analysis_progress_*`, not `user_notifications_*`.

- [ ] **Step 3: Rewrite PdfAnalysisJob broadcast methods**

Replace `app/jobs/pdf_analysis_job.rb` entirely:

```ruby
class PdfAnalysisJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, wait: 5.seconds, attempts: 2
  discard_on ActiveJob::DeserializationError

  def perform(property_id: nil, user_id:, document_blob_ids: nil)
    @user = User.find(user_id)
    @property = Property.find(property_id) if property_id

    result = if document_blob_ids
      documents = ActiveStorage::Blob.where(id: document_blob_ids).to_a
      PdfAnalysisService.call(documents: documents, user: @user)
    else
      PdfAnalysisService.call(property: @property, user: @user)
    end

    if result.success?
      @property = result.property
      broadcast_toast("분석 완료", :success,
        action_url: inspect_tab_url(result.property.id),
        action_label: "결과 보기")
      broadcast_indicator(active: false)
    else
      broadcast_toast(result.error, :danger)
      broadcast_indicator(active: false)
    end
  rescue Faraday::TimeoutError => e
    Rails.logger.error "[PdfAnalysisJob] Timeout: #{e.message}"
    broadcast_toast("AI 서버 응답 시간이 초과되었습니다. 자동 재시도됩니다.", :danger)
    broadcast_indicator(active: false)
    raise
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
    broadcast_toast("분석 중 오류가 발생했습니다: #{e.message}", :danger)
    broadcast_indicator(active: false)
  end

  private

  def channel_name
    "user_notifications_#{@user.id}"
  end

  def broadcast_toast(message, type, action_url: nil, action_label: nil)
    Turbo::StreamsChannel.broadcast_append_to(
      channel_name,
      target: "global_toasts",
      partial: "notifications/toast",
      locals: { message: message, type: type, action_url: action_url, action_label: action_label }
    )
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Toast broadcast failed: #{e.message}"
  end

  def broadcast_indicator(active:)
    Turbo::StreamsChannel.broadcast_replace_to(
      channel_name,
      target: "analysis_indicator",
      partial: "notifications/analysis_indicator",
      locals: { active: active }
    )
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Indicator broadcast failed: #{e.message}"
  end

  def inspect_tab_url(property_id)
    Rails.application.routes.url_helpers.edit_property_inspections_tab_path(
      property_id, tab_key: "rights_analysis"
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/jobs/pdf_analysis_job_test.rb`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/pdf_analysis_job.rb test/jobs/pdf_analysis_job_test.rb
git commit -m "feat(job): broadcast to global notification channel with toast and indicator"
```

---

## Task 6: Update AnalysesController for Immediate Feedback

**Files:**
- Modify: `app/controllers/analyses_controller.rb`
- Modify: `test/controllers/analyses_controller_test.rb`

- [ ] **Step 1: Write failing tests for new Turbo Stream response**

Replace the Turbo Stream test in `test/controllers/analyses_controller_test.rb`:

```ruby
test "POST create with Turbo responds with form reset, toast, and indicator" do
  pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

  post analyses_path, params: { documents: [pdf] },
    headers: { "Accept" => "text/vnd.turbo-stream.html" }

  assert_response :success
  assert_includes response.content_type, "text/vnd.turbo-stream.html"
  assert_includes response.body, 'action="replace"'
  assert_includes response.body, 'target="analysis_form"'
  assert_includes response.body, 'action="append"'
  assert_includes response.body, 'target="global_toasts"'
  assert_includes response.body, "분석이 시작되었습니다"
  assert_includes response.body, 'target="analysis_indicator"'
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyses_controller_test.rb`

Expected: FAIL — response doesn't contain `global_toasts` or `analysis_indicator` targets.

- [ ] **Step 3: Update AnalysesController#create**

Replace `app/controllers/analyses_controller.rb`:

```ruby
class AnalysesController < ApplicationController
  def new
  end

  def create
    uploaded_files = Array(params[:documents]).reject { |f| f.is_a?(String) }

    if uploaded_files.empty?
      redirect_to new_analysis_path, alert: "PDF 파일을 업로드해주세요."
      return
    end

    blob_ids = uploaded_files.map do |file|
      unless file.content_type == "application/pdf"
        redirect_to new_analysis_path, alert: "PDF 파일만 업로드할 수 있습니다."
        return
      end
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type
      ).id
    end

    PdfAnalysisJob.perform_later(
      property_id: nil,
      user_id: current_user.id,
      document_blob_ids: blob_ids
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("analysis_form", partial: "analyses/form"),
          turbo_stream.append("global_toasts", partial: "notifications/toast",
            locals: { message: "분석이 시작되었습니다", type: :info }),
          turbo_stream.replace("analysis_indicator", partial: "notifications/analysis_indicator",
            locals: { active: true })
        ]
      end
      format.html do
        redirect_to new_analysis_path, notice: "분석이 시작되었습니다."
      end
    end
  end
end
```

- [ ] **Step 4: Create the form partial for reset**

Extract the form from `app/views/analyses/new.html.erb` into a new partial. Create `app/views/analyses/_form.html.erb`:

```erb
<div id="analysis_form" data-controller="file-upload">
  <%= form_with url: analyses_path, method: :post, class: "space-y-3", data: { action: "submit->file-upload#submit" } do |f| %>
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses_controller_test.rb`

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/analyses_controller.rb app/views/analyses/_form.html.erb test/controllers/analyses_controller_test.rb
git commit -m "feat(analyses): immediate toast and indicator feedback on analysis start"
```

---

## Task 7: Update Inspections::StartController for Indicator Broadcast

**Files:**
- Modify: `app/controllers/inspections/start_controller.rb`
- Modify: `test/controllers/inspections/start_controller_test.rb`

- [ ] **Step 1: Write failing test for indicator broadcast**

Update the enqueue test in `test/controllers/inspections/start_controller_test.rb`:

```ruby
test "enqueues PdfAnalysisJob and broadcasts indicator" do
  pdf_blob = ActiveStorage::Blob.create_and_upload!(
    io: StringIO.new("%PDF-1.4 test"),
    filename: "test.pdf",
    content_type: "application/pdf"
  )
  @property.documents.attach(pdf_blob)

  assert_enqueued_with(job: PdfAnalysisJob) do
    post property_inspections_start_url(@property)
  end
  assert_redirected_to property_path(@property)
  assert_equal "분석이 시작되었습니다.", flash[:notice]
end
```

Note: The existing test already covers the redirect + flash + job enqueue. The indicator broadcast happens via Turbo Stream broadcast (server-side), so it's tested implicitly. We add an explicit broadcast assertion:

```ruby
test "broadcasts analysis indicator on start" do
  pdf_blob = ActiveStorage::Blob.create_and_upload!(
    io: StringIO.new("%PDF-1.4 test"),
    filename: "test.pdf",
    content_type: "application/pdf"
  )
  @property.documents.attach(pdf_blob)

  user = users(:guest)
  assert_broadcasts("user_notifications_#{user.id}", 1) do
    post property_inspections_start_url(@property)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/inspections/start_controller_test.rb`

Expected: FAIL — no broadcasts to `user_notifications_*` channel.

- [ ] **Step 3: Update StartController to broadcast indicator**

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

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_notifications_#{current_user.id}",
        target: "analysis_indicator",
        partial: "notifications/analysis_indicator",
        locals: { active: true }
      )

      redirect_to property_path(@property), notice: "분석이 시작되었습니다."
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/inspections/start_controller_test.rb`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/inspections/start_controller.rb test/controllers/inspections/start_controller_test.rb
git commit -m "feat(inspections): broadcast analysis indicator on start"
```

---

## Task 8: Clean Up Views — Remove Inline Progress UI

**Files:**
- Modify: `app/views/analyses/new.html.erb`
- Modify: `app/views/properties/show.html.erb`
- Delete: `app/views/analyses/_progress.html.erb`

- [ ] **Step 1: Update analyses/new.html.erb**

Replace `app/views/analyses/new.html.erb` — remove the page-level subscription and progress div, use the new form partial:

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

      <%= render "analyses/form" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Update properties/show.html.erb**

In `app/views/properties/show.html.erb`, remove the last 4 lines (the `#analysis_progress` div and its Turbo Stream subscription):

Remove:
```erb
  <div id="analysis_progress">
    <%= turbo_stream_from "analysis_progress_#{current_user.id}" %>
  </div>
</div>
```

Replace with just the closing `</div>`:
```erb
</div>
```

- [ ] **Step 3: Delete the progress partial**

```bash
rm app/views/analyses/_progress.html.erb
```

- [ ] **Step 4: Run full test suite to verify nothing is broken**

Run: `bin/rails test`

Expected: All tests pass. No references to `_progress` partial remain in active code paths.

- [ ] **Step 5: Commit**

```bash
git add app/views/analyses/new.html.erb app/views/properties/show.html.erb
git rm app/views/analyses/_progress.html.erb
git commit -m "refactor: remove inline progress UI, use form partial and global notifications"
```

---

## Task 9: Final Integration Verification

- [ ] **Step 1: Run full test suite**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 2: Run linter**

```bash
bin/rubocop
```

Expected: No new offenses.

- [ ] **Step 3: Run security check**

```bash
bin/brakeman --quiet --no-pager
```

Expected: No new warnings.

- [ ] **Step 4: Manual smoke test (if dev server available)**

Start `bin/dev` and verify:
1. Navigate to `/analyses/new` — upload form appears, no progress div
2. Upload a PDF and submit — toast "분석이 시작되었습니다" appears, header shows spinner, form resets
3. Navigate to another page — spinner persists in header
4. Wait for analysis completion — success toast with "결과 보기" link appears, spinner disappears
5. Click "결과 보기" — navigates to inspection results
6. Repeat from `/properties/:id` — same behavior via flash notice + indicator broadcast
