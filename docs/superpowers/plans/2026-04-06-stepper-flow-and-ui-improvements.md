# Stepper Flow & UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement sequential stepper flow (checklist → rights analysis → rating) with UI improvements, document verification step, and 만원 currency unit standardization.

**Architecture:** Minimal change approach — modify existing controllers, components, and Stimulus controllers. Add one new ViewComponent (`DocumentVerificationComponent`), one DB migration, one new controller action (`confirm`), and one new route.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus (JS), Minitest, TailwindCSS

**Spec:** `docs/superpowers/specs/2026-04-06-stepper-flow-and-ui-improvements-design.md`

---

## File Map

| File | Responsibility |
|------|---------------|
| `db/migrate/XXXXXX_add_user_confirmed_at_to_rights_analysis_reports.rb` | Add `user_confirmed_at` column |
| `test/fixtures/rights_analysis_reports.yml` | Add `user_confirmed_at` to fixtures |
| `config/routes.rb` | Add `confirm` route for reports |
| `app/components/stepper_component.html.erb` | Always show step numbers |
| `app/components/stepper_component.rb` | Change `step_completed?(:report)` condition |
| `test/components/stepper_component_test.rb` | Update tests for new completion logic |
| `app/views/analyses/checklists/edit.html.erb` | Rename button |
| `app/views/analyses/ratings/show.html.erb` | Add "권리 분석 진행" button |
| `app/services/rights_analysis_service.rb` | Fix nil/false guard in `compute_verdict` |
| `test/services/rights_analysis_service_test.rb` | Add test for nil/false fields |
| `app/components/report_summary_component.rb` | Accept `property:`, add checklist summary |
| `app/components/report_summary_component.html.erb` | Label change, prices, summary |
| `test/components/report_summary_component_test.rb` | Update tests |
| `app/views/analyses/reports/show.html.erb` | Pass property to component, add verification |
| `app/components/document_verification_component.rb` | New: document verification logic |
| `app/components/document_verification_component.html.erb` | New: document verification UI |
| `test/components/document_verification_component_test.rb` | New: tests |
| `app/controllers/analyses/reports_controller.rb` | Add `confirm` action, 만원 parsing |
| `app/javascript/controllers/dividend_simulator_controller.js` | Natural language parsing + 만원 format |
| `app/components/dividend_simulator_component.rb` | 만원 format helper |
| `app/components/dividend_simulator_component.html.erb` | 만원 unit labels |
| `test/components/dividend_simulator_component_test.rb` | Update tests |
| `app/views/analyses/ratings/show.html.erb` | Dual grade card display |
| `test/integration/rights_analysis_flow_test.rb` | Update integration test |

---

### Task 1: Migration — Add `user_confirmed_at` to `rights_analysis_reports`

**Files:**
- Create: `db/migrate/XXXXXX_add_user_confirmed_at_to_rights_analysis_reports.rb`
- Modify: `test/fixtures/rights_analysis_reports.yml`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddUserConfirmedAtToRightsAnalysisReports user_confirmed_at:datetime
```

Expected: Migration file created in `db/migrate/`

- [ ] **Step 2: Run migration**

Run:
```bash
bin/rails db:migrate
```

Expected: `rights_analysis_reports` table now has `user_confirmed_at` column. Verify with:
```bash
bin/rails runner "puts RightsAnalysisReport.column_names.include?('user_confirmed_at')"
```
Expected output: `true`

- [ ] **Step 3: Update fixtures**

In `test/fixtures/rights_analysis_reports.yml`, add `user_confirmed_at: nil` to both fixtures to be explicit:

```yaml
safe_apartment_report:
  user: budget_user
  property: safe_apartment
  base_right_type: "근저당"
  base_right_date: "2024-01-15"
  base_right_holder: "국민은행"
  assumed_amount: 0
  total_risk_amount: 0
  verdict: 0
  verdict_summary: "말소기준권리: 근저당 (2024-01-15, 국민은행)\n임차인 없음\n인수 금액 0원"
  source_doc_reviewed: false
  analyzed_at: <%= Time.current %>
  user_confirmed_at:
  report_data: '<%= { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }.to_json %>'

risky_villa_report:
  user: guest
  property: risky_villa
  base_right_type: "근저당"
  base_right_date: "2023-06-01"
  base_right_holder: "신한은행"
  assumed_amount: 30000000
  total_risk_amount: 30000000
  verdict: 2
  verdict_summary: "말소기준권리: 근저당 (2023-06-01, 신한은행)\n대항력 있는 임차인 1명 — 보증금 3,000만원 인수\n유치권 신고 있음"
  opportunity_type:
  opportunity_reason:
  source_doc_reviewed: false
  analyzed_at: <%= Time.current %>
  user_confirmed_at:
  report_data: '<%= { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 30000000, unconfirmed_risk: 0, total_burden: 30000000, verdict: "danger" }, checklist_references: ["rights-011"] }.to_json %>'
```

- [ ] **Step 4: Run tests to ensure nothing breaks**

Run:
```bash
bin/rails test
```

Expected: All existing tests pass.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_user_confirmed_at_to_rights_analysis_reports.rb db/schema.rb test/fixtures/rights_analysis_reports.yml
git commit -m "feat: add user_confirmed_at to rights_analysis_reports"
```

---

### Task 2: Stepper — Always Show Numbers + New Completion Logic

**Files:**
- Modify: `app/components/stepper_component.html.erb:14-18`
- Modify: `app/components/stepper_component.rb:35-38`
- Modify: `test/components/stepper_component_test.rb`

- [ ] **Step 1: Write failing test for always-show-numbers**

In `test/components/stepper_component_test.rb`, replace the existing "marks completed steps with checkmark" test and add a new test:

```ruby
test "always shows step numbers even when completed" do
  UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
  render_inline(StepperComponent.new(property: @property, user: @user, active_step: :report))
  assert_selector "[data-step-status='completed']", text: "1."
  assert_no_text "✓"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
bin/rails test test/components/stepper_component_test.rb -n "test_always_shows_step_numbers_even_when_completed"
```

Expected: FAIL — currently shows ✓ for completed steps.

- [ ] **Step 3: Update stepper template to always show numbers**

In `app/components/stepper_component.html.erb`, replace lines 14-18:

```erb
        <% if step[:status] == :completed %>
          <span class="text-xs">✓</span>
        <% else %>
          <span class="text-xs"><%= step[:number] %>.</span>
        <% end %>
```

With:

```erb
        <span class="text-xs"><%= step[:number] %>.</span>
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
bin/rails test test/components/stepper_component_test.rb -n "test_always_shows_step_numbers_even_when_completed"
```

Expected: PASS

- [ ] **Step 5: Write failing test for new report completion logic**

In `test/components/stepper_component_test.rb`, add:

```ruby
test "report step is pending when user_confirmed_at is nil" do
  UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
  report = RightsAnalysisReport.find_or_create_by!(user: @user, property: @property) do |r|
    r.verdict = :safe
    r.verdict_summary = "test"
    r.analyzed_at = Time.current
  end
  report.update!(user_confirmed_at: nil)
  render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
  assert_selector "[data-step-status='pending'][data-step-key='report']"
end

test "report step is completed when user_confirmed_at is present" do
  UserProperty.find_or_create_by!(user: @user, property: @property).update!(analyzed_at: Time.current)
  report = RightsAnalysisReport.find_or_create_by!(user: @user, property: @property) do |r|
    r.verdict = :safe
    r.verdict_summary = "test"
    r.analyzed_at = Time.current
  end
  report.update!(user_confirmed_at: Time.current)
  render_inline(StepperComponent.new(property: @property, user: @user, active_step: :checklist))
  assert_selector "[data-step-status='completed'][data-step-key='report']"
end
```

- [ ] **Step 6: Run tests to verify they fail**

Run:
```bash
bin/rails test test/components/stepper_component_test.rb -n "test_report_step_is_pending_when_user_confirmed_at_is_nil" -n "test_report_step_is_completed_when_user_confirmed_at_is_present"
```

Expected: First test should FAIL (currently `report.present?` returns true).

- [ ] **Step 7: Update `step_completed?` in stepper_component.rb**

In `app/components/stepper_component.rb`, change the `step_completed?` method (lines 35-38):

```ruby
  def step_completed?(key)
    case key
    when :checklist then user_property&.analyzed_at.present?
    when :report then report&.user_confirmed_at.present?
    when :rating then user_property&.safety_rating.present?
    end
  end
```

- [ ] **Step 8: Run all stepper tests**

Run:
```bash
bin/rails test test/components/stepper_component_test.rb
```

Expected: All PASS.

- [ ] **Step 9: Commit**

```bash
git add app/components/stepper_component.rb app/components/stepper_component.html.erb test/components/stepper_component_test.rb
git commit -m "feat: stepper always shows numbers, report completion requires user_confirmed_at"
```

---

### Task 3: Route + Confirm Action

**Files:**
- Modify: `config/routes.rb:34`
- Modify: `app/controllers/analyses/reports_controller.rb`

- [ ] **Step 1: Write failing integration test for confirm action**

In `test/integration/rights_analysis_flow_test.rb`, add:

```ruby
test "confirm action sets user_confirmed_at and redirects to rating" do
  RightsAnalysisService.call(property: @property, user: @user)
  report = RightsAnalysisReport.find_by(user: @user, property: @property)
  assert_nil report.user_confirmed_at

  patch confirm_property_analyses_report_url(@property)
  assert_redirected_to property_analyses_rating_url(@property)

  report.reload
  assert_not_nil report.user_confirmed_at
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
bin/rails test test/integration/rights_analysis_flow_test.rb -n "test_confirm_action_sets_user_confirmed_at_and_redirects_to_rating"
```

Expected: FAIL — route does not exist yet.

- [ ] **Step 3: Add route**

In `config/routes.rb`, change line 34:

```ruby
      resource :report, only: [ :show, :update ], controller: "reports"
```

To:

```ruby
      resource :report, only: [ :show, :update ], controller: "reports" do
        patch :confirm
      end
```

- [ ] **Step 4: Add confirm action to controller**

In `app/controllers/analyses/reports_controller.rb`, add the `confirm` method:

```ruby
module Analyses
  class ReportsController < ApplicationController
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

    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid]&.to_i
      registry_data = @property.raw_data&.dig("registry_transcript")
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []
      seizures = (registry_data&.dig("seizures") || [])

      rights = (registry_data&.dig("rights") || [])

      simulation = RightsAnalysis::DividendSimulator.call(
        rights: rights, tenants: tenants, seizures: seizures,
        expected_bid: expected_bid
      )

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = simulation.slice(:expected_bid, :distribution).deep_stringify_keys
      report_data["bidder_burden"] = simulation[:bidder_burden].deep_stringify_keys
      @report.update!(report_data: report_data)

      redirect_to property_analyses_report_url(@property)
    end

    def confirm
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)
      @report.update!(user_confirmed_at: Time.current)
      redirect_to property_analyses_rating_url(@property)
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
bin/rails test test/integration/rights_analysis_flow_test.rb -n "test_confirm_action_sets_user_confirmed_at_and_redirects_to_rating"
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/analyses/reports_controller.rb test/integration/rights_analysis_flow_test.rb
git commit -m "feat: add confirm action for rights analysis report"
```

---

### Task 4: Checklist Button Rename + Rating Screen Navigation

**Files:**
- Modify: `app/views/analyses/checklists/edit.html.erb:17`
- Modify: `app/views/analyses/ratings/show.html.erb`

- [ ] **Step 1: Rename checklist submit button**

In `app/views/analyses/checklists/edit.html.erb`, change line 17:

```erb
        <%= f.submit "등급 산정",
```

To:

```erb
        <%= f.submit "물건 등급 확인하기",
```

- [ ] **Step 2: Add "권리 분석 진행" button to rating screen**

Replace the entire content of `app/views/analyses/ratings/show.html.erb`:

```erb
<%# app/views/analyses/ratings/show.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-6">
    <%= render RatingResultComponent.new(property: @property, risk_results: @risk_results, rating: @rating) %>

    <div class="flex justify-center gap-3">
      <%= button_to "다시 분석하기", property_analyses_start_path(@property), method: :post,
          class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" %>
      <%= link_to "권리 분석 진행", property_analyses_report_path(@property),
          class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700",
          data: { turbo_frame: "tab_content" } %>
      <%= link_to "목록으로 돌아가기", properties_path,
          class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600",
          data: { turbo_frame: "_top" } %>
    </div>
  </div>
<% end %>
```

Key changes:
- "권리 분석 진행" is now the primary (blue) button
- "목록으로 돌아가기" is now secondary (slate) style

- [ ] **Step 3: Run existing tests to verify nothing broke**

Run:
```bash
bin/rails test test/controllers/analyses/checklists_controller_test.rb
```

Expected: All PASS (redirect target unchanged — still goes to rating).

- [ ] **Step 4: Commit**

```bash
git add app/views/analyses/checklists/edit.html.erb app/views/analyses/ratings/show.html.erb
git commit -m "feat: rename checklist button, add rights analysis navigation to rating"
```

---

### Task 5: Fix "false" Bug in `compute_verdict`

**Files:**
- Modify: `app/services/rights_analysis_service.rb:98-114`
- Modify: `test/services/rights_analysis_service_test.rb`

- [ ] **Step 1: Write failing test for nil/false fields**

In `test/services/rights_analysis_service_test.rb`, add:

```ruby
test "compute_verdict handles nil and false field values gracefully" do
  # Create a property with problematic raw_data (boolean false as type)
  property = PropertyDataSyncService.call(case_number: "2026타경10001")
  report = RightsAnalysisService.call(property: property, user: @user)

  # Verify no "false" string appears in verdict_summary
  assert_not_includes report.verdict_summary, "false"
  assert_not_includes report.verdict_summary, "nil"
end
```

- [ ] **Step 2: Run test**

Run:
```bash
bin/rails test test/services/rights_analysis_service_test.rb -n "test_compute_verdict_handles_nil_and_false_field_values_gracefully"
```

If this passes (mock data may be clean), we still apply the defensive fix. If it fails, we fix it next.

- [ ] **Step 3: Add nil/false guards to compute_verdict**

In `app/services/rights_analysis_service.rb`, replace the `compute_verdict` method (lines 87-115):

```ruby
  def compute_verdict(base_right, tenants, assumed, check_results)
    has_lien = check_results.any? { |r| r.checklist_item.code == "rights-011" && r.has_risk == true }

    verdict = if has_lien || assumed[:assumed_amount] > 0
      :danger
    elsif assumed[:total_risk_amount] > 0
      :caution
    else
      :safe
    end

    lines = []
    if base_right && base_right[:type].present?
      lines << "말소기준권리: #{base_right[:type]} (#{base_right[:date]}, #{base_right[:holder]})"
    else
      lines << "말소기준권리: 해당 없음"
    end

    opposing = tenants.select { |t| t[:has_opposing_power] == true }
    if opposing.any?
      lines << "대항력 있는 임차인 #{opposing.size}명 — 인수 금액 #{format_amount(assumed[:assumed_amount])}"
    else
      lines << tenants.any? ? "임차인 #{tenants.size}명 — 대항력 없음, 인수 금액 0원" : "임차인 없음"
    end

    lines << "유치권 신고 있음" if has_lien

    [ verdict, lines.join("\n") ]
  end
```

Key changes:
- `base_right[:type].present?` instead of just truthy check on `base_right` — catches `false` and `""` values
- `t[:has_opposing_power] == true` explicit boolean comparison — prevents `"false"` strings or `false` booleans from being truthy

- [ ] **Step 4: Run all rights analysis tests**

Run:
```bash
bin/rails test test/services/rights_analysis_service_test.rb
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/rights_analysis_service.rb test/services/rights_analysis_service_test.rb
git commit -m "fix: guard against nil/false values in verdict_summary generation"
```

---

### Task 6: ReportSummaryComponent — Label, Prices, Checklist Summary

**Files:**
- Modify: `app/components/report_summary_component.rb`
- Modify: `app/components/report_summary_component.html.erb`
- Modify: `app/views/analyses/reports/show.html.erb:4`
- Modify: `test/components/report_summary_component_test.rb`

- [ ] **Step 1: Write failing tests**

Replace `test/components/report_summary_component_test.rb` entirely:

```ruby
require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders safe verdict with checklist label" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "체크리스트 분석 결과"
    assert_no_text "권리 분석 판정"
    assert_text "안전"
    assert_text "말소기준권리"
  end

  test "renders danger verdict" do
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "위험"
  end

  test "renders appraisal price and min bid price" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "감정가"
    assert_text "최저매각가"
  end

  test "renders checklist review summary" do
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "체크리스트 검토"
  end

  test "renders opportunity badge when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.opportunity_type = "hug_waiver"
    report.opportunity_reason = "HUG가 대항력을 포기"
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "안전 기회 물건"
  end

  test "renders assumed amount" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "인수 금액"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/components/report_summary_component_test.rb
```

Expected: FAIL — wrong number of arguments (missing `property:`), label still says "권리 분석 판정".

- [ ] **Step 3: Update report_summary_component.rb**

Replace `app/components/report_summary_component.rb`:

```ruby
class ReportSummaryComponent < ViewComponent::Base
  VERDICT_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", border: "border-green-300", emoji: "🟢", label: "안전" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", border: "border-yellow-300", emoji: "🟡", label: "주의" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", border: "border-red-300", emoji: "🔴", label: "위험" }
  }.freeze

  CHECKLIST_CODE_LABELS = {
    "rights-003" => "선순위 전세권 위험",
    "rights-006" => "대항력 있는 임차인 위험",
    "rights-009" => "HUG 확약서 미제출",
    "rights-011" => "유치권 신고 있음"
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @config = VERDICT_CONFIG[report.verdict] || VERDICT_CONFIG["safe"]
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def checklist_summary
    refs = @report.report_data&.dig("checklist_references") || []
    return "위험 항목 없음" if refs.empty?

    refs.map { |code| CHECKLIST_CODE_LABELS[code] || code }.join(", ")
  end

  def format_amount(amount)
    return "0원" if amount.nil? || amount == 0
    amount.to_fs(:delimited) + "원"
  end

  def format_price(price_in_manwon)
    return "—" if price_in_manwon.nil? || price_in_manwon == 0

    if price_in_manwon >= 10000
      eok = price_in_manwon / 10000
      remainder = price_in_manwon % 10000
      remainder > 0 ? "#{eok}억 #{remainder.to_fs(:delimited)}만원" : "#{eok}억원"
    else
      "#{price_in_manwon.to_fs(:delimited)}만원"
    end
  end
end
```

- [ ] **Step 4: Update report_summary_component.html.erb**

Replace `app/components/report_summary_component.html.erb`:

```erb
<div class="rounded-xl border-2 p-6 <%= @config[:border] %> <%= @config[:bg] %>">
  <div class="flex items-start gap-6">
    <div class="text-center shrink-0">
      <div class="text-4xl"><%= @config[:emoji] %></div>
      <div class="text-xl font-bold mt-1 <%= @config[:color] %>"><%= @config[:label] %></div>
      <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">체크리스트 분석 결과</div>
    </div>
    <div class="flex-1 min-w-0">
      <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">핵심 근거</div>
      <div class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-line leading-relaxed"><%= @report.verdict_summary %></div>
      <div class="mt-3 text-sm">
        <span class="font-semibold text-slate-900 dark:text-slate-100">체크리스트 검토:</span>
        <span class="text-slate-600 dark:text-slate-400"><%= checklist_summary %></span>
      </div>
    </div>
    <div class="shrink-0 space-y-3">
      <div class="text-center rounded-lg bg-white/60 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 p-3">
        <div class="text-xs text-slate-500 dark:text-slate-400">감정가</div>
        <div class="text-base font-bold text-slate-900 dark:text-slate-100"><%= format_price(@property.appraisal_price) %></div>
        <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">최저매각가</div>
        <div class="text-base font-semibold text-slate-900 dark:text-slate-100"><%= format_price(@property.min_bid_price) %></div>
      </div>
      <div class="text-center rounded-lg bg-white/60 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 p-3">
        <div class="text-xs text-slate-500 dark:text-slate-400">인수 금액</div>
        <div class="text-base font-bold text-slate-900 dark:text-slate-100"><%= format_amount(@report.assumed_amount) %></div>
        <div class="text-xs text-slate-500 dark:text-slate-400 mt-1">총 위험 금액</div>
        <div class="text-base font-semibold text-slate-900 dark:text-slate-100"><%= format_amount(@report.total_risk_amount) %></div>
      </div>
    </div>
  </div>

  <% if opportunity? %>
    <div class="mt-4 flex items-center gap-2 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-300 dark:border-amber-600 px-4 py-3">
      <span class="text-lg">💡</span>
      <div class="flex-1">
        <div class="text-sm font-semibold text-amber-800 dark:text-amber-200">안전 기회 물건</div>
        <div class="text-xs text-amber-700 dark:text-amber-300"><%= @report.opportunity_reason %></div>
      </div>
      <span class="text-xs text-amber-600 dark:text-amber-400 bg-amber-100 dark:bg-amber-900/40 px-2 py-1 rounded">⚠️ 추정치</span>
    </div>
  <% end %>

  <div class="mt-4 text-xs text-slate-500 dark:text-slate-400">
    본 분석은 AI가 생성한 참고 자료이며, 법적 효력이 없습니다. 투자 판단에 따른 책임은 이용자 본인에게 있습니다.
  </div>
</div>
```

- [ ] **Step 5: Update reports/show.html.erb to pass property**

In `app/views/analyses/reports/show.html.erb`, change line 4:

```erb
    <%= render ReportSummaryComponent.new(report: @report) %>
```

To:

```erb
    <%= render ReportSummaryComponent.new(report: @report, property: @property) %>
```

- [ ] **Step 6: Run tests**

Run:
```bash
bin/rails test test/components/report_summary_component_test.rb
```

Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add app/components/report_summary_component.rb app/components/report_summary_component.html.erb app/views/analyses/reports/show.html.erb test/components/report_summary_component_test.rb
git commit -m "feat: update report summary with checklist label, prices, and review summary"
```

---

### Task 7: DocumentVerificationComponent

**Files:**
- Create: `app/components/document_verification_component.rb`
- Create: `app/components/document_verification_component.html.erb`
- Create: `test/components/document_verification_component_test.rb`
- Modify: `app/views/analyses/reports/show.html.erb`

- [ ] **Step 1: Write failing tests**

Create `test/components/document_verification_component_test.rb`:

```ruby
require "test_helper"

class DocumentVerificationComponentTest < ViewComponent::TestCase
  test "renders verification prompt" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "물건명세서 및 건축물대장과 동일한지 확인"
  end

  test "renders key analysis items from verdict_summary" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "말소기준권리"
  end

  test "renders confirm button" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_selector "input[type='submit'][value='예, 동일합니다']"
  end

  test "renders disabled no button" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_selector "button[disabled]", text: "아니오"
  end

  test "shows already confirmed state" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.user_confirmed_at = Time.current
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "확인 완료"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/components/document_verification_component_test.rb
```

Expected: FAIL — class does not exist.

- [ ] **Step 3: Create document_verification_component.rb**

Create `app/components/document_verification_component.rb`:

```ruby
class DocumentVerificationComponent < ViewComponent::Base
  def initialize(report:, property:)
    @report = report
    @property = property
  end

  private

  def confirmed?
    @report.user_confirmed_at.present?
  end

  def key_items
    @report.verdict_summary&.split("\n")&.reject(&:blank?) || []
  end
end
```

- [ ] **Step 4: Create document_verification_component.html.erb**

Create `app/components/document_verification_component.html.erb`:

```erb
<div class="rounded-xl border-2 border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 p-6">
  <div class="flex items-center gap-2 mb-4">
    <span class="text-lg">📋</span>
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">서류 확인</h3>
  </div>

  <% if confirmed? %>
    <div class="flex items-center gap-2 rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-300 dark:border-green-600 px-4 py-3">
      <span class="text-lg">✅</span>
      <span class="text-sm font-medium text-green-700 dark:text-green-400">확인 완료 — <%= @report.user_confirmed_at.strftime("%Y-%m-%d %H:%M") %></span>
    </div>
  <% else %>
    <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
      아래 분석 내용이 물건명세서 및 건축물대장과 동일한지 확인해주세요.
    </p>

    <ul class="space-y-2 mb-6">
      <% key_items.each do |item| %>
        <li class="flex items-start gap-2 text-sm text-slate-700 dark:text-slate-300">
          <span class="text-slate-400 mt-0.5">•</span>
          <span><%= item %></span>
        </li>
      <% end %>
    </ul>

    <div class="flex gap-3">
      <%= button_to "예, 동일합니다",
          helpers.confirm_property_analyses_report_path(@property),
          method: :patch,
          class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 cursor-pointer" %>
      <button type="button" disabled
          class="inline-flex items-center rounded-md bg-slate-200 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-400 dark:text-slate-500 cursor-not-allowed"
          title="추후 지원 예정">
        아니오
      </button>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run tests**

Run:
```bash
bin/rails test test/components/document_verification_component_test.rb
```

Expected: All PASS.

- [ ] **Step 6: Add component to reports/show.html.erb**

In `app/views/analyses/reports/show.html.erb`, add the component before `LegalDisclaimerComponent`:

```erb
<%# app/views/analyses/reports/show.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-8">
    <%= render ReportSummaryComponent.new(report: @report, property: @property) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(property: @property) %>
    <%= render DocumentVerificationComponent.new(report: @report, property: @property) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

- [ ] **Step 7: Run all tests**

Run:
```bash
bin/rails test
```

Expected: All PASS.

- [ ] **Step 8: Commit**

```bash
git add app/components/document_verification_component.rb app/components/document_verification_component.html.erb test/components/document_verification_component_test.rb app/views/analyses/reports/show.html.erb
git commit -m "feat: add document verification component for rights analysis confirmation"
```

---

### Task 8: Dividend Simulation — 만원 Unit (Stimulus Controller)

**Files:**
- Modify: `app/javascript/controllers/dividend_simulator_controller.js`

- [ ] **Step 1: Rewrite dividend_simulator_controller.js with 만원 parsing**

Replace `app/javascript/controllers/dividend_simulator_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bidInput", "hiddenBid"]

  connect() {
    this.formatDisplay()
  }

  formatInput() {
    const manwon = this.parseToManwon(this.bidInputTarget.value)
    this.bidInputTarget.value = this.formatManwon(manwon)
    this.hiddenBidTarget.value = manwon || ""
  }

  formatDisplay() {
    const raw = this.bidInputTarget.value
    if (raw && !isNaN(Number(raw))) {
      this.bidInputTarget.value = this.formatManwon(Number(raw))
    }
  }

  parseToManwon(input) {
    if (!input) return null
    let str = input.replace(/[\s,]/g, "")

    let total = 0

    const eokMatch = str.match(/(\d+)억/)
    if (eokMatch) {
      total += parseInt(eokMatch[1], 10) * 10000
      str = str.replace(/\d+억/, "")
    }

    const cheonMatch = str.match(/(\d+)천/)
    if (cheonMatch) {
      total += parseInt(cheonMatch[1], 10) * 1000
      str = str.replace(/\d+천/, "")
    }

    str = str.replace(/만원|만/, "")

    const remaining = str.replace(/[^0-9]/g, "")
    if (remaining) {
      total += parseInt(remaining, 10)
    }

    return total > 0 ? total : null
  }

  formatManwon(manwon) {
    if (!manwon || manwon === 0) return ""

    if (manwon >= 10000) {
      const eok = Math.floor(manwon / 10000)
      const remainder = manwon % 10000
      if (remainder === 0) return `${eok}억원`
      return `${eok}억 ${remainder.toLocaleString()}만원`
    }

    return `${manwon.toLocaleString()}만원`
  }
}
```

- [ ] **Step 2: Verify the controller connects properly**

Run:
```bash
bin/rails test
```

Expected: All existing tests pass (JS controller changes don't affect Ruby tests).

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/dividend_simulator_controller.js
git commit -m "feat: dividend simulator parses natural language input to manwon unit"
```

---

### Task 9: Dividend Simulation — 만원 Unit (Component + Server)

**Files:**
- Modify: `app/components/dividend_simulator_component.html.erb`
- Modify: `app/components/dividend_simulator_component.rb`
- Modify: `app/controllers/analyses/reports_controller.rb:19-20`
- Modify: `test/components/dividend_simulator_component_test.rb`

- [ ] **Step 1: Write failing test for 만원 display**

In `test/components/dividend_simulator_component_test.rb`, add:

```ruby
test "displays unit as manwon" do
  report = rights_analysis_reports(:safe_apartment_report)
  report.report_data = { "dividend_simulation" => { "expected_bid" => nil, "distribution" => [] }, "bidder_burden" => { "assumed_amount" => 0, "unconfirmed_risk" => 0, "total_burden" => 0, "verdict" => "safe" } }
  property = properties(:safe_apartment)
  render_inline(DividendSimulatorComponent.new(report: report, property: property))
  assert_text "만원"
  assert_no_selector "span", text: /\A원\z/
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
bin/rails test test/components/dividend_simulator_component_test.rb -n "test_displays_unit_as_manwon"
```

Expected: FAIL — currently shows "원".

- [ ] **Step 3: Update dividend_simulator_component.rb**

Replace `app/components/dividend_simulator_component.rb`:

```ruby
class DividendSimulatorComponent < ViewComponent::Base
  BURDEN_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", message: "추가 인수 부담이 없는 구조입니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", message: "미확인 위험 금액이 존재합니다. 확인이 필요합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", message: "인수 금액이 추가 발생하는 구조입니다" }
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @simulation = report.report_data&.dig("dividend_simulation") || {}
    @burden = report.report_data&.dig("bidder_burden") || {}
  end

  private

  def expected_bid
    @simulation["expected_bid"]
  end

  def distribution
    @simulation["distribution"] || []
  end

  def burden_config
    BURDEN_CONFIG[@burden["verdict"]] || BURDEN_CONFIG["safe"]
  end

  def format_manwon(amount)
    return "—" if amount.nil?
    manwon = amount.to_i

    if manwon >= 10000
      eok = manwon / 10000
      remainder = manwon % 10000
      remainder > 0 ? "#{eok}억 #{remainder.to_fs(:delimited)}만원" : "#{eok}억원"
    elsif manwon > 0
      "#{manwon.to_fs(:delimited)}만원"
    else
      "0만원"
    end
  end
end
```

- [ ] **Step 4: Update dividend_simulator_component.html.erb**

Replace `app/components/dividend_simulator_component.html.erb`:

```erb
<div class="space-y-4">
  <div class="flex items-center gap-3">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">배당 시뮬레이션</h3>
    <span class="text-xs text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-2 py-1 rounded">⚠️ 추정치 — 실제 배당과 다를 수 있습니다</span>
  </div>

  <%= form_with url: helpers.property_analyses_report_path(@property), method: :patch, class: "flex items-center gap-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg border border-slate-200 dark:border-slate-700 p-3",
      data: { controller: "dividend-simulator" } do |f| %>
    <label class="text-sm font-semibold text-slate-700 dark:text-slate-300 whitespace-nowrap">예상 낙찰가</label>
    <input type="text" value="<%= expected_bid %>"
           inputmode="numeric" placeholder="금액을 입력하세요"
           class="flex-1 rounded-md border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 px-3 py-2 text-sm text-slate-900 dark:text-slate-100"
           data-dividend-simulator-target="bidInput"
           data-action="input->dividend-simulator#formatInput" />
    <input type="hidden" name="expected_bid" data-dividend-simulator-target="hiddenBid" value="<%= expected_bid %>" />
    <span class="text-sm text-slate-500 dark:text-slate-400">만원</span>
    <%= f.submit "계산", class: "rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 cursor-pointer" %>
  <% end %>

  <% if distribution.any? %>
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-slate-100 dark:bg-slate-800">
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">순위</th>
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">채권자</th>
            <th class="px-3 py-2 text-left font-medium text-slate-600 dark:text-slate-400">유형</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">채권액</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">배당액</th>
            <th class="px-3 py-2 text-right font-medium text-slate-600 dark:text-slate-400">미배당</th>
          </tr>
        </thead>
        <tbody>
          <% distribution.each do |row| %>
            <tr class="border-b border-slate-100 dark:border-slate-800">
              <td class="px-3 py-2 text-slate-700 dark:text-slate-300"><%= row["priority"] %></td>
              <td class="px-3 py-2 font-medium text-slate-900 dark:text-slate-100"><%= row["holder"] %></td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-400"><%= row["type"] %></td>
              <td class="px-3 py-2 text-right text-slate-700 dark:text-slate-300"><%= format_manwon(row["claim"]) %></td>
              <td class="px-3 py-2 text-right font-semibold text-green-700 dark:text-green-400"><%= format_manwon(row["dividend"]) %></td>
              <td class="px-3 py-2 text-right <%= row["shortfall"].to_i > 0 ? 'text-red-600 dark:text-red-400' : 'text-slate-500 dark:text-slate-400' %>"><%= format_manwon(row["shortfall"]) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>

  <div class="rounded-lg border p-4 <%= burden_config[:bg] %>">
    <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">💰 낙찰자 부담 분석</div>
    <div class="grid grid-cols-3 gap-4 text-sm mb-3">
      <div>
        <span class="text-slate-500 dark:text-slate-400">인수 금액</span>
        <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_manwon(@burden["assumed_amount"]) %></p>
      </div>
      <div>
        <span class="text-slate-500 dark:text-slate-400">미확인 위험</span>
        <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_manwon(@burden["unconfirmed_risk"]) %></p>
      </div>
      <div>
        <span class="text-slate-500 dark:text-slate-400">실질 부담 총액</span>
        <p class="font-bold text-slate-900 dark:text-slate-100"><%= format_manwon(@burden["total_burden"]) %></p>
      </div>
    </div>
    <div class="text-sm font-medium <%= burden_config[:color] %>">
      <% if @burden["verdict"] == "safe" %>✅<% elsif @burden["verdict"] == "caution" %>⚠️<% else %>🔴<% end %>
      <%= burden_config[:message] %>
    </div>
  </div>

  <div class="text-xs text-slate-500 dark:text-slate-400">
    정확한 배당 결과는 법원 배당표를 확인하세요.
  </div>
</div>
```

Key changes:
- Input uses visible field for display + hidden field `hiddenBid` for form submission
- Unit label: "원" → "만원"
- All `format_amount` calls → `format_manwon`
- Burden section no longer appends "원" after amount

- [ ] **Step 5: Update server-side parsing in ReportsController**

In `app/controllers/analyses/reports_controller.rb`, change the `update` method's `expected_bid` line:

```ruby
    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].present? ? params[:expected_bid].to_i : nil
      registry_data = @property.raw_data&.dig("registry_transcript")
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []
      seizures = (registry_data&.dig("seizures") || [])

      rights = (registry_data&.dig("rights") || [])

      simulation = RightsAnalysis::DividendSimulator.call(
        rights: rights, tenants: tenants, seizures: seizures,
        expected_bid: expected_bid
      )

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = simulation.slice(:expected_bid, :distribution).deep_stringify_keys
      report_data["bidder_burden"] = simulation[:bidder_burden].deep_stringify_keys
      @report.update!(report_data: report_data)

      redirect_to property_analyses_report_url(@property)
    end
```

Note: The value arrives as 만원 integer from the hidden field. The `DividendSimulator` now operates in 만원 units. No conversion needed server-side — the hidden field already holds the parsed 만원 integer from the Stimulus controller.

- [ ] **Step 6: Update existing dividend component tests**

Replace `test/components/dividend_simulator_component_test.rb`:

```ruby
require "test_helper"

class DividendSimulatorComponentTest < ViewComponent::TestCase
  test "renders bid input form with manwon unit" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "dividend_simulation" => { "expected_bid" => nil, "distribution" => [] }, "bidder_burden" => { "assumed_amount" => 0, "unconfirmed_risk" => 0, "total_burden" => 0, "verdict" => "safe" } }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_selector "input[name='expected_bid']"
    assert_text "예상 낙찰가"
    assert_text "만원"
  end

  test "renders distribution table when simulation exists" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    report.report_data = {
      "dividend_simulation" => {
        "expected_bid" => 15000,
        "distribution" => [
          { "priority" => 0, "holder" => "경매 비용", "type" => "경매 비용", "claim" => 300, "dividend" => 300, "shortfall" => 0 }
        ]
      },
      "bidder_burden" => { "assumed_amount" => 0, "unconfirmed_risk" => 0, "total_burden" => 0, "verdict" => "safe" }
    }
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "경매 비용"
  end

  test "renders bidder burden summary" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "dividend_simulation" => {}, "bidder_burden" => { "assumed_amount" => 0, "unconfirmed_risk" => 0, "total_burden" => 0, "verdict" => "safe" } }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "낙찰자 부담 분석"
  end

  test "displays unit as manwon" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "dividend_simulation" => { "expected_bid" => nil, "distribution" => [] }, "bidder_burden" => { "assumed_amount" => 0, "unconfirmed_risk" => 0, "total_burden" => 0, "verdict" => "safe" } }
    property = properties(:safe_apartment)
    render_inline(DividendSimulatorComponent.new(report: report, property: property))
    assert_text "만원"
  end
end
```

- [ ] **Step 7: Run tests**

Run:
```bash
bin/rails test test/components/dividend_simulator_component_test.rb
```

Expected: All PASS.

- [ ] **Step 8: Commit**

```bash
git add app/components/dividend_simulator_component.rb app/components/dividend_simulator_component.html.erb app/controllers/analyses/reports_controller.rb test/components/dividend_simulator_component_test.rb
git commit -m "feat: convert dividend simulation to manwon unit with natural language input"
```

---

### Task 10: Rating Screen — Dual Grade Display

**Files:**
- Modify: `app/views/analyses/ratings/show.html.erb`
- Modify: `app/controllers/analyses/ratings_controller.rb`

- [ ] **Step 1: Update ratings controller to load report**

Replace `app/controllers/analyses/ratings_controller.rb`:

```ruby
module Analyses
  class RatingsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @active_step = :rating
      @rating = SafetyRatingService.call(property: @property, user: current_user)
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)
      @risk_results = @property.property_check_results
        .where(has_risk: true, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
  end
end
```

- [ ] **Step 2: Update ratings/show.html.erb with dual grade cards**

Replace `app/views/analyses/ratings/show.html.erb`:

```erb
<%# app/views/analyses/ratings/show.html.erb %>
<%= render layout: "analyses/layout", locals: { property: @property, user_property: @user_property, active_step: @active_step } do %>
  <div class="space-y-6">
    <% if @report %>
      <div class="grid grid-cols-2 gap-4">
        <%= render RatingResultComponent.new(property: @property, risk_results: @risk_results, rating: @rating, label: "체크리스트 등급") %>
        <%= render RatingResultComponent.new(property: @property, risk_results: [], rating: @report.verdict, label: "권리 분석 등급") %>
      </div>
    <% else %>
      <%= render RatingResultComponent.new(property: @property, risk_results: @risk_results, rating: @rating) %>
    <% end %>

    <% if @risk_results.any? %>
      <div class="space-y-3">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">위험 항목 상세</h3>
        <% @risk_results.each do |result| %>
          <details class="rounded-lg border border-slate-200 dark:border-slate-700">
            <summary class="cursor-pointer px-4 py-3 text-sm font-medium text-slate-900 dark:text-slate-100">
              <%= result.checklist_item.question %>
              <span class="ml-2 text-xs <%= result.resolvable ? 'text-yellow-600' : 'text-red-600' %>">
                <%= result.resolvable ? "해결 가능" : "해결 불가" %>
              </span>
            </summary>
            <div class="border-t border-slate-200 dark:border-slate-700 px-4 py-3 text-sm text-slate-600 dark:text-slate-400">
              <p><%= result.checklist_item.description %></p>
              <% if result.resolution_note.present? %>
                <p class="mt-2 font-medium">메모: <%= result.resolution_note %></p>
              <% end %>
            </div>
          </details>
        <% end %>
      </div>
    <% end %>

    <div class="flex justify-center gap-3">
      <%= button_to "다시 분석하기", property_analyses_start_path(@property), method: :post,
          class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" %>
      <%= link_to "권리 분석 진행", property_analyses_report_path(@property),
          class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700",
          data: { turbo_frame: "tab_content" } %>
      <%= link_to "목록으로 돌아가기", properties_path,
          class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600",
          data: { turbo_frame: "_top" } %>
    </div>
  </div>
<% end %>
```

Note: The risk details section is now inline in the view rather than in the component template, because the dual card layout requires separating the grade display from the details. The `RatingResultComponent` template only renders the grade card, not the details section.

- [ ] **Step 3: Update RatingResultComponent to accept optional label**

In `app/components/rating_result_component.rb`:

```ruby
# frozen_string_literal: true

class RatingResultComponent < ViewComponent::Base
  RATING_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", label: "안전", description: "위험 항목이 없습니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", label: "주의", description: "위험 항목이 있으나 모두 해결 가능합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", label: "경고", description: "해결 불가능한 위험 항목이 있습니다" }
  }.freeze

  def initialize(property:, risk_results:, rating: nil, label: nil)
    @property = property
    @risk_results = risk_results
    @label = label
    @config = RATING_CONFIG[rating.to_s] || RATING_CONFIG["safe"]
  end
end
```

- [ ] **Step 4: Update rating_result_component.html.erb**

Replace `app/components/rating_result_component.html.erb`:

```erb
<div class="rounded-xl border-2 p-8 text-center <%= @config[:bg] %>">
  <div class="text-4xl font-bold <%= @config[:color] %>"><%= @config[:label] %></div>
  <p class="mt-2 text-sm text-slate-600 dark:text-slate-400"><%= @config[:description] %></p>
  <% if @label %>
    <p class="mt-1 text-xs text-slate-500 dark:text-slate-400"><%= @label %></p>
  <% end %>
</div>
```

Note: Risk details moved to the view in the previous step.

- [ ] **Step 5: Run existing rating result tests**

Run:
```bash
bin/rails test test/components/rating_result_component_test.rb
```

Expected: All PASS (new `label` param is optional, risk_results no longer rendered in template but tests check component output).

If the danger test fails due to `assert_selector "details"`, update it:

```ruby
test "renders danger rating" do
  property = properties(:risky_villa)
  result = property_check_results(:risky_villa_rights_011)
  render_inline(RatingResultComponent.new(property: property, risk_results: [ result ], rating: :danger))
  assert_text "경고"
end
```

- [ ] **Step 6: Run all tests**

Run:
```bash
bin/rails test
```

Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/analyses/ratings_controller.rb app/views/analyses/ratings/show.html.erb app/components/rating_result_component.rb app/components/rating_result_component.html.erb test/components/rating_result_component_test.rb
git commit -m "feat: rating screen shows dual grade cards (checklist + rights analysis)"
```

---

### Task 11: Integration Test Update

**Files:**
- Modify: `test/integration/rights_analysis_flow_test.rb`

- [ ] **Step 1: Update integration test for full flow**

In `test/integration/rights_analysis_flow_test.rb`, update the existing "dividend simulation updates report" test to use 만원 units, and add a full flow test:

```ruby
test "dividend simulation updates report with manwon unit" do
  RightsAnalysisService.call(property: @property, user: @user)

  patch property_analyses_report_url(@property), params: { expected_bid: 15000 }
  assert_redirected_to property_analyses_report_url(@property)

  report = RightsAnalysisReport.find_by(user: @user, property: @property)
  assert_equal 15000, report.report_data.dig("dividend_simulation", "expected_bid")
  assert report.report_data.dig("dividend_simulation", "distribution").any?
end

test "full sequential flow: checklist → rating → report → confirm → final rating" do
  # Step 0: Start analysis
  post property_analyses_start_url(@property)
  assert_redirected_to edit_property_analyses_checklist_url(@property)

  # Step 1: Complete checklist
  @property.property_check_results.where(source_type: nil, user: @user).each do |r|
    r.update!(source_type: "manual", has_risk: false)
  end
  patch property_analyses_checklist_url(@property), params: { resolutions: {} }
  assert_redirected_to property_analyses_rating_url(@property)

  # Step 1.5: View rating, then go to report
  get property_analyses_report_url(@property)
  assert_response :success

  # Step 2: Confirm document verification
  patch confirm_property_analyses_report_url(@property)
  assert_redirected_to property_analyses_rating_url(@property)

  report = RightsAnalysisReport.find_by(user: @user, property: @property)
  assert_not_nil report.user_confirmed_at

  # Step 3: View final rating
  get property_analyses_rating_url(@property)
  assert_response :success
end
```

- [ ] **Step 2: Remove or update the old dividend test that uses 원 units**

Find and update the existing test "dividend simulation updates report" — replace `100_000_000` with `15000` (만원) and update the assertion. If there are two similar tests now, remove the old one.

- [ ] **Step 3: Run all integration tests**

Run:
```bash
bin/rails test test/integration/rights_analysis_flow_test.rb
```

Expected: All PASS.

- [ ] **Step 4: Run full test suite**

Run:
```bash
bin/rails test
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add test/integration/rights_analysis_flow_test.rb
git commit -m "test: update integration tests for sequential stepper flow and manwon unit"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
bin/rails test
```

Expected: All PASS.

- [ ] **Step 2: Run linter**

```bash
bin/rubocop
```

Fix any issues found.

- [ ] **Step 3: Run security checks**

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Expected: No warnings.

- [ ] **Step 4: Verify seed data works**

```bash
bin/rails db:reset
```

Expected: Seeds load without errors.

- [ ] **Step 5: Commit any fixes**

If any fixes were needed:
```bash
git add -A
git commit -m "chore: fix lint and security warnings"
```
