# Analysis Report Screen & PDF Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the 최종등급 tab into a comprehensive analysis report with PDF export for offline professional consultation.

**Architecture:** Enhance existing `GradesController#show` with 4 new ViewComponents (PropertyInfoComponent, BudgetSummaryComponent, BidOpinionComponent, ConsultationGuideComponent) and add Playwright-based HTML→PDF export via `PdfExportService`. CSS is inlined in the PDF layout to avoid Puma deadlock.

**Tech Stack:** Rails 8.1, ViewComponent, Playwright (existing gem), Tailwind CSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-13-analysis-report-and-pdf-export-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Create | `app/components/property_info_component.rb` | Property basic info card |
| Create | `app/components/property_info_component.html.erb` | Property info template |
| Create | `test/components/property_info_component_test.rb` | Property info tests |
| Create | `app/components/budget_summary_component.rb` | Budget settings summary card |
| Create | `app/components/budget_summary_component.html.erb` | Budget summary template |
| Create | `test/components/budget_summary_component_test.rb` | Budget summary tests (existing file — extend) |
| Create | `app/components/bid_opinion_component.rb` | Rule-based bid recommendation |
| Create | `app/components/bid_opinion_component.html.erb` | Bid opinion template |
| Create | `test/components/bid_opinion_component_test.rb` | Bid opinion tests |
| Create | `app/components/consultation_guide_component.rb` | Dynamic expert consultation guide |
| Create | `app/components/consultation_guide_component.html.erb` | Consultation guide template |
| Create | `test/components/consultation_guide_component_test.rb` | Consultation guide tests |
| Create | `app/services/pdf_export_service.rb` | Playwright HTML→PDF conversion |
| Create | `test/services/pdf_export_service_test.rb` | PDF export service tests |
| Create | `app/views/layouts/report_pdf.html.erb` | PDF-only layout with inlined CSS |
| Create | `app/views/inspections/grades/show.pdf.erb` | PDF template (same components, no interactive elements) |
| Modify | `app/controllers/inspections/grades_controller.rb` | Add `@budget_setting`, `respond_to` for PDF |
| Modify | `app/views/inspections/grades/show.html.erb` | Add new components, remove SourceDocViewer, add PDF button |
| Modify | `app/components/rights_report_section_component.html.erb` | Remove SourceDocViewerComponent render |
| Modify | `test/controllers/inspections/grades_controller_test.rb` | Add PDF format test |
| Modify | `Dockerfile` | Add chromium + fonts-noto-cjk |

---

### Task 1: PropertyInfoComponent

**Files:**
- Create: `app/components/property_info_component.rb`
- Create: `app/components/property_info_component.html.erb`
- Create: `test/components/property_info_component_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/components/property_info_component_test.rb
require "test_helper"

class PropertyInfoComponentTest < ViewComponent::TestCase
  test "renders case number" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "2026타경10001"
  end

  test "renders address" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "서울특별시 강남구 역삼동 100-1"
  end

  test "renders property type" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "아파트"
  end

  test "renders appraisal price formatted" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "8억"
  end

  test "renders min bid price formatted" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "5억 6,000만원"
  end

  test "renders exclusive area" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "84.5㎡"
  end

  test "renders failed bid count" do
    property = properties(:risky_villa)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "2회"
  end

  test "renders dash for missing claim amount" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "—"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/property_info_component_test.rb`
Expected: Error — `NameError: uninitialized constant PropertyInfoComponent`

- [ ] **Step 3: Implement component**

```ruby
# app/components/property_info_component.rb
class PropertyInfoComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(property:)
    @property = property
  end

  private

  def fields
    [
      { label: "사건번호", value: @property.case_number },
      { label: "소재지", value: @property.address },
      { label: "물건유형", value: @property.property_type },
      { label: "감정가", value: format_price_won(@property.appraisal_price) },
      { label: "최저매각가격", value: format_price_won(@property.min_bid_price) },
      { label: "전용면적", value: @property.exclusive_area.present? ? "#{@property.exclusive_area}㎡" : "—" },
      { label: "유찰횟수", value: @property.failed_bid_count.present? ? "#{@property.failed_bid_count}회" : "0회" },
      { label: "청구금액", value: format_price_won(@property.claim_amount) }
    ]
  end
end
```

```erb
<%# app/components/property_info_component.html.erb %>
<div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-4">
  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3">물건 기본 정보</h3>
  <dl class="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
    <% fields.each do |field| %>
      <div class="flex justify-between py-1 border-b border-slate-100 dark:border-slate-700/50">
        <dt class="text-slate-500 dark:text-slate-400"><%= field[:label] %></dt>
        <dd class="font-medium text-slate-900 dark:text-slate-100 text-right"><%= field[:value] %></dd>
      </div>
    <% end %>
  </dl>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/property_info_component_test.rb`
Expected: 8 tests, 8 assertions, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/components/property_info_component.rb app/components/property_info_component.html.erb test/components/property_info_component_test.rb
git commit -m "feat(components): add PropertyInfoComponent for report screen"
```

---

### Task 2: BudgetSummaryComponent (for report)

The existing `test/components/budget_summary_component_test.rb` tests a different component used in onboarding. This is a new component for the report screen — name it `ReportBudgetComponent` to avoid conflict.

**Files:**
- Create: `app/components/report_budget_component.rb`
- Create: `app/components/report_budget_component.html.erb`
- Create: `test/components/report_budget_component_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/components/report_budget_component_test.rb
require "test_helper"

class ReportBudgetComponentTest < ViewComponent::TestCase
  test "renders available cash" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "3억"
  end

  test "renders loan ratio as percentage" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "70%"
  end

  test "renders max bid amount formatted" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "9억 6,200만원"
  end

  test "renders total reserves" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "1,140만원"
  end

  test "renders prompt when budget is nil" do
    render_inline(ReportBudgetComponent.new(budget_setting: nil))
    assert_text "예산 설정을 먼저 완료해주세요"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/report_budget_component_test.rb`
Expected: Error — `NameError: uninitialized constant ReportBudgetComponent`

- [ ] **Step 3: Implement component**

```ruby
# app/components/report_budget_component.rb
class ReportBudgetComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(budget_setting:)
    @budget = budget_setting
  end

  def render?
    true
  end

  private

  def fields
    [
      { label: "가용 자금", value: format_price_in_eok(@budget.available_cash) },
      { label: "대출 비율", value: "#{(@budget.loan_ratio * 100).to_i}%" },
      { label: "최대 입찰가", value: format_price_in_eok(@budget.max_bid_amount) },
      { label: "예비비 합계", value: format_price_in_eok(@budget.total_reserves) },
      { label: "선택 지역", value: @budget.region || "—" }
    ]
  end
end
```

```erb
<%# app/components/report_budget_component.html.erb %>
<% if @budget %>
  <div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-4">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3">예산 설정 요약</h3>
    <dl class="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
      <% fields.each do |field| %>
        <div class="flex justify-between py-1 border-b border-slate-100 dark:border-slate-700/50">
          <dt class="text-slate-500 dark:text-slate-400"><%= field[:label] %></dt>
          <dd class="font-medium text-slate-900 dark:text-slate-100 text-right"><%= field[:value] %></dd>
        </div>
      <% end %>
    </dl>
  </div>
<% else %>
  <div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/50 p-4 text-center text-sm text-slate-500 dark:text-slate-400">
    예산 설정을 먼저 완료해주세요
  </div>
<% end %>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/report_budget_component_test.rb`
Expected: 5 tests, 5 assertions, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/components/report_budget_component.rb app/components/report_budget_component.html.erb test/components/report_budget_component_test.rb
git commit -m "feat(components): add ReportBudgetComponent for report screen"
```

---

### Task 3: BidOpinionComponent

**Files:**
- Create: `app/components/bid_opinion_component.rb`
- Create: `app/components/bid_opinion_component.html.erb`
- Create: `test/components/bid_opinion_component_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/components/bid_opinion_component_test.rb
require "test_helper"

class BidOpinionComponentTest < ViewComponent::TestCase
  test "renders safe verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능합니다"
  end

  test "renders danger verdict with unresolvable items" do
    risk_results = InspectionResult.where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
    render_inline(BidOpinionComponent.new(
      rating: :danger,
      report: rights_analysis_reports(:risky_villa_report),
      risk_results: risk_results.includes(:inspection_item),
      budget_setting: budget_settings(:completed),
      property: properties(:risky_villa)
    ))
    assert_text "입찰을 권하지 않습니다"
  end

  test "renders caution verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :caution,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능하나 확인 필요"
  end

  test "renders incomplete verdict" do
    render_inline(BidOpinionComponent.new(
      rating: :incomplete,
      report: nil,
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "분석이 완료되지 않았습니다"
  end

  test "renders key figures table" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: budget_settings(:completed),
      property: properties(:safe_apartment)
    ))
    assert_text "감정가"
    assert_text "최저매각가격"
    assert_text "인수금액"
    assert_text "최대 입찰가"
  end

  test "renders without budget setting" do
    render_inline(BidOpinionComponent.new(
      rating: :safe,
      report: rights_analysis_reports(:safe_apartment_report),
      risk_results: [],
      budget_setting: nil,
      property: properties(:safe_apartment)
    ))
    assert_text "입찰 검토 가능합니다"
    assert_text "감정가"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/bid_opinion_component_test.rb`
Expected: Error — `NameError: uninitialized constant BidOpinionComponent`

- [ ] **Step 3: Implement component**

```ruby
# app/components/bid_opinion_component.rb
class BidOpinionComponent < ViewComponent::Base
  include ApplicationHelper

  VERDICT_CONFIG = {
    safe: {
      label: "입찰 검토 가능합니다",
      bg: "bg-green-50 dark:bg-green-900/20 border-green-300 dark:border-green-700",
      text: "text-green-800 dark:text-green-200",
      icon_bg: "bg-green-100 dark:bg-green-800/40"
    },
    caution: {
      label: "입찰 검토 가능하나 확인 필요",
      bg: "bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-700",
      text: "text-yellow-800 dark:text-yellow-200",
      icon_bg: "bg-yellow-100 dark:bg-yellow-800/40"
    },
    danger: {
      label: "입찰을 권하지 않습니다",
      bg: "bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-700",
      text: "text-red-800 dark:text-red-200",
      icon_bg: "bg-red-100 dark:bg-red-800/40"
    },
    incomplete: {
      label: "분석이 완료되지 않았습니다",
      bg: "bg-slate-50 dark:bg-slate-800/50 border-slate-300 dark:border-slate-600",
      text: "text-slate-700 dark:text-slate-300",
      icon_bg: "bg-slate-100 dark:bg-slate-700"
    }
  }.freeze

  def initialize(rating:, report:, risk_results:, budget_setting:, property:)
    @rating = rating
    @report = report
    @risk_results = risk_results
    @budget = budget_setting
    @property = property
    @config = VERDICT_CONFIG[rating] || VERDICT_CONFIG[:incomplete]
  end

  private

  def reasoning
    case @rating
    when :danger
      unresolvable = @risk_results.select { |r| r.resolvable == false }
      items = unresolvable.map { |r| r.inspection_item.question }.join(", ")
      "해소 불가능한 위험 항목 #{unresolvable.size}건: #{items}"
    when :caution
      resolvable = @risk_results.select { |r| r.resolvable == true }
      "해소 가능한 위험 항목 #{resolvable.size}건. 전문가 확인 권장."
    when :safe
      "위험 항목이 없습니다."
    when :incomplete
      "미입력 항목이 있습니다. 분석 완료 후 재확인하세요."
    end
  end

  def key_figures
    figures = [
      { label: "감정가", value: format_price_won(@property.appraisal_price) },
      { label: "최저매각가격", value: format_price_won(@property.min_bid_price) }
    ]

    if @report
      figures << { label: "인수금액", value: format_price_won(@report.assumed_amount) }
      figures << { label: "총 위험금액", value: format_price_won(@report.total_risk_amount) }
      figures << { label: "대항력 있는 임차인", value: "#{opposing_tenant_count}명" }
    end

    if @budget
      figures << { label: "최대 입찰가 (예산)", value: format_price_in_eok(@budget.max_bid_amount) }
    end

    if bidder_burden.present?
      figures << { label: "낙찰자 부담액", value: format_price_won(bidder_burden) }
    end

    figures
  end

  def opposing_tenant_count
    return 0 unless @report
    @report.effective_tenants.count { |t| t["opposing_power"] }
  end

  def bidder_burden
    @report&.parsed_data&.dig("user_simulation", "bidder_burden")
  end
end
```

```erb
<%# app/components/bid_opinion_component.html.erb %>
<div class="rounded-lg border-2 p-5 <%= @config[:bg] %>">
  <h3 class="text-lg font-bold <%= @config[:text] %>"><%= @config[:label] %></h3>
  <p class="mt-1 text-sm <%= @config[:text] %> opacity-80"><%= reasoning %></p>

  <div class="mt-4 grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
    <% key_figures.each do |fig| %>
      <div class="flex justify-between py-1.5 border-b border-black/5 dark:border-white/5">
        <span class="text-slate-600 dark:text-slate-400"><%= fig[:label] %></span>
        <span class="font-semibold text-slate-900 dark:text-slate-100"><%= fig[:value] %></span>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/bid_opinion_component_test.rb`
Expected: 6 tests, all pass

- [ ] **Step 5: Commit**

```bash
git add app/components/bid_opinion_component.rb app/components/bid_opinion_component.html.erb test/components/bid_opinion_component_test.rb
git commit -m "feat(components): add BidOpinionComponent with rule-based bid recommendation"
```

---

### Task 4: ConsultationGuideComponent

**Files:**
- Create: `app/components/consultation_guide_component.rb`
- Create: `app/components/consultation_guide_component.html.erb`
- Create: `test/components/consultation_guide_component_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/components/consultation_guide_component_test.rb
require "test_helper"

class ConsultationGuideComponentTest < ViewComponent::TestCase
  test "not rendered when no risk results" do
    render_inline(ConsultationGuideComponent.new(risk_results: []))
    assert_no_text "전문가 상담 가이드"
  end

  test "renders rights analysis professional for rights tab risks" do
    risk_results = InspectionResult
      .where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
      .includes(:inspection_item)
    render_inline(ConsultationGuideComponent.new(risk_results: risk_results))
    assert_text "법무사/변호사"
  end

  test "renders section title when risks exist" do
    risk_results = InspectionResult
      .where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
      .includes(:inspection_item)
    render_inline(ConsultationGuideComponent.new(risk_results: risk_results))
    assert_text "전문가 상담 가이드"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/consultation_guide_component_test.rb`
Expected: Error — `NameError: uninitialized constant ConsultationGuideComponent`

- [ ] **Step 3: Implement component**

```ruby
# app/components/consultation_guide_component.rb
class ConsultationGuideComponent < ViewComponent::Base
  PROFESSIONALS = {
    "rights_analysis" => { title: "법무사/변호사", scope: "등기 권리관계 확인 및 인수 여부 판단" },
    "property_analysis" => { title: "법무사 + 건축사", scope: "건축물 하자, 위반건축물 확인" },
    "profit_analysis" => { title: "세무사 + 은행/대출 컨설턴트", scope: "취득세, 양도세 계산 및 대출 가능 여부 확인" },
    "field_check" => { title: "공인중개사", scope: "현장 상태 확인 및 시세 검증" },
    "bidding" => { title: "법무사", scope: "입찰 절차 및 보증금 관련 확인" }
  }.freeze

  def initialize(risk_results:)
    @risk_results = risk_results
  end

  def render?
    @risk_results.any?
  end

  private

  def grouped_recommendations
    @risk_results
      .group_by { |r| r.inspection_item.tab }
      .filter_map do |tab, results|
        prof = PROFESSIONALS[tab]
        next unless prof
        { professional: prof, items: results }
      end
  end
end
```

```erb
<%# app/components/consultation_guide_component.html.erb %>
<div class="space-y-3">
  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">전문가 상담 가이드</h3>
  <% grouped_recommendations.each do |rec| %>
    <div class="rounded-lg border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 p-4">
      <div class="font-semibold text-blue-800 dark:text-blue-200"><%= rec[:professional][:title] %> 상담 권장</div>
      <p class="text-sm text-blue-600 dark:text-blue-400 mt-0.5"><%= rec[:professional][:scope] %></p>
      <ul class="mt-2 space-y-1">
        <% rec[:items].each do |result| %>
          <li class="text-sm text-blue-700 dark:text-blue-300">
            • <span class="font-mono text-xs"><%= result.inspection_item.code %></span> <%= result.inspection_item.question %>
          </li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/consultation_guide_component_test.rb`
Expected: 3 tests, all pass

- [ ] **Step 5: Commit**

```bash
git add app/components/consultation_guide_component.rb app/components/consultation_guide_component.html.erb test/components/consultation_guide_component_test.rb
git commit -m "feat(components): add ConsultationGuideComponent with dynamic expert matching"
```

---

### Task 5: Update report view and controller

**Files:**
- Modify: `app/controllers/inspections/grades_controller.rb`
- Modify: `app/views/inspections/grades/show.html.erb`
- Modify: `app/components/rights_report_section_component.html.erb`
- Modify: `test/controllers/inspections/grades_controller_test.rb`

- [ ] **Step 1: Write failing controller test**

Add to the existing test file:

```ruby
# test/controllers/inspections/grades_controller_test.rb
# Add this test to the existing class:

test "show assigns budget_setting" do
  get property_inspections_grade_url(@property)
  assert_response :success
end
```

- [ ] **Step 2: Update GradesController**

Replace the full content of `app/controllers/inspections/grades_controller.rb`:

```ruby
module Inspections
  class GradesController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @rating = InspectionRatingService.call(property: @property, user: current_user)
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)
      @budget_setting = current_user.budget_setting

      @results_by_tab = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
        .group_by { |r| r.inspection_item.tab }

      @risk_results = @property.inspection_results
        .where(has_risk: true, user: current_user)
        .includes(:inspection_item)
        .order("inspection_items.tab, inspection_items.tab_position")
    end
  end
end
```

- [ ] **Step 3: Remove SourceDocViewerComponent from RightsReportSectionComponent**

In `app/components/rights_report_section_component.html.erb`, remove the line:

```erb
<%= render SourceDocViewerComponent.new(report: @report, property: @property) %>
```

- [ ] **Step 4: Update the grade view**

Replace the full content of `app/views/inspections/grades/show.html.erb`:

```erb
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: "grade" } do %>
  <div class="space-y-6">
    <%= render PropertyInfoComponent.new(property: @property) %>
    <%= render ReportBudgetComponent.new(budget_setting: @budget_setting) %>
    <%= render GradeSummaryComponent.new(rating: @rating) %>
    <%= render BidOpinionComponent.new(
      rating: @rating,
      report: @report,
      risk_results: @risk_results,
      budget_setting: @budget_setting,
      property: @property
    ) %>
    <%= render TabSummaryTableComponent.new(results_by_tab: @results_by_tab, property: @property) %>

    <% if @risk_results.any? %>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">위험 항목 상세</h3>
      <%= render RiskItemsListComponent.new(risk_results: @risk_results) %>
    <% end %>

    <%= render RightsReportSectionComponent.new(report: @report, property: @property) %>
    <%= render ConsultationGuideComponent.new(risk_results: @risk_results) %>

    <div class="flex gap-3">
      <%= link_to property_inspections_grade_path(@property, format: :pdf),
          class: "flex-1 rounded-lg bg-blue-600 dark:bg-blue-500 px-4 py-3 text-sm font-semibold text-center text-white hover:bg-blue-700 dark:hover:bg-blue-600 transition-colors",
          data: { turbo: false } do %>
        PDF 다운로드
      <% end %>
      <%= link_to "목록으로 돌아가기", properties_path, class: "flex-1 rounded-lg border border-slate-300 dark:border-slate-600 px-4 py-3 text-sm font-semibold text-center text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 5: Run all tests**

Run: `bin/rails test`
Expected: All tests pass (existing + new component tests)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/inspections/grades_controller.rb app/views/inspections/grades/show.html.erb app/components/rights_report_section_component.html.erb test/controllers/inspections/grades_controller_test.rb
git commit -m "feat: integrate report components into grade view

Add PropertyInfoComponent, ReportBudgetComponent, BidOpinionComponent,
ConsultationGuideComponent to the grade view. Remove SourceDocViewerComponent.
Add PDF download button."
```

---

### Task 6: PdfExportService and PDF layout

**Files:**
- Create: `app/services/pdf_export_service.rb`
- Create: `test/services/pdf_export_service_test.rb`
- Create: `app/views/layouts/report_pdf.html.erb`
- Create: `app/views/inspections/grades/show.pdf.erb`
- Modify: `app/controllers/inspections/grades_controller.rb`

- [ ] **Step 1: Write failing service test**

```ruby
# test/services/pdf_export_service_test.rb
require "test_helper"

class PdfExportServiceTest < ActiveSupport::TestCase
  test "generates PDF binary from HTML" do
    html = <<~HTML
      <!DOCTYPE html>
      <html><head><style>body { font-family: sans-serif; }</style></head>
      <body><h1>Test PDF</h1><p>Korean text: 테스트 문서</p></body></html>
    HTML

    result = PdfExportService.call(html: html)
    assert result.present?, "PDF binary should not be empty"
    assert result.start_with?("%PDF"), "Output should be a valid PDF"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/pdf_export_service_test.rb`
Expected: Error — `NameError: uninitialized constant PdfExportService`

- [ ] **Step 3: Implement PdfExportService**

```ruby
# app/services/pdf_export_service.rb
class PdfExportService
  def self.call(html:)
    new(html: html).call
  end

  def initialize(html:)
    @html = html
  end

  def call
    Playwright.create(playwright_cli_executable_path: find_playwright_cli) do |playwright|
      playwright.chromium.launch(
        headless: true,
        args: chromium_args,
        executablePath: chromium_executable
      ) do |browser|
        page = browser.new_page
        page.set_content(@html, waitUntil: "networkidle")
        page.pdf(
          format: "A4",
          margin: { top: "20mm", bottom: "20mm", left: "15mm", right: "15mm" },
          printBackground: true
        )
      end
    end
  end

  private

  def chromium_executable
    ENV.fetch("PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH", nil)
  end

  def chromium_args
    %w[--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage]
  end

  def find_playwright_cli
    ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "npx playwright")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/pdf_export_service_test.rb`
Expected: 1 test, 1 assertion, 0 failures

Note: This test requires Playwright and Chromium to be available in the dev environment. If not available, mark as pending and test manually.

- [ ] **Step 5: Create PDF layout**

```erb
<%# app/views/layouts/report_pdf.html.erb %>
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <style>
    <%= Rails.application.assets.load_path.find("tailwind.css")&.content&.html_safe %>
  </style>
  <style>
    @media print {
      .no-print { display: none !important; }
      .print-break { break-before: page; page-break-before: always; }
    }
    body { font-family: "Noto Sans CJK KR", "Noto Sans KR", sans-serif; }
    /* Force light theme for PDF */
    .dark\:bg-slate-800 { background-color: white !important; }
    .dark\:text-slate-100 { color: #1e293b !important; }
    .dark\:text-slate-200 { color: #334155 !important; }
    .dark\:text-slate-300 { color: #475569 !important; }
    .dark\:text-slate-400 { color: #64748b !important; }
    .dark\:border-slate-700 { border-color: #e2e8f0 !important; }
  </style>
</head>
<body class="bg-white text-slate-900 p-0 m-0">
  <div class="max-w-4xl mx-auto">
    <%= yield %>
  </div>
</body>
</html>
```

- [ ] **Step 6: Create PDF template**

```erb
<%# app/views/inspections/grades/show.pdf.erb %>
<div class="space-y-6 p-4">
  <h1 class="text-2xl font-bold text-center text-slate-900 mb-2">경매 분석 리포트</h1>
  <p class="text-center text-sm text-slate-500 mb-6">생성일: <%= Date.current.strftime("%Y년 %m월 %d일") %></p>

  <%= render PropertyInfoComponent.new(property: @property) %>
  <%= render ReportBudgetComponent.new(budget_setting: @budget_setting) %>
  <%= render GradeSummaryComponent.new(rating: @rating) %>
  <%= render BidOpinionComponent.new(
    rating: @rating,
    report: @report,
    risk_results: @risk_results,
    budget_setting: @budget_setting,
    property: @property
  ) %>

  <div class="print-break"></div>
  <%= render TabSummaryTableComponent.new(results_by_tab: @results_by_tab, property: @property) %>

  <% if @risk_results.any? %>
    <h3 class="text-lg font-semibold text-slate-900">위험 항목 상세</h3>
    <%= render RiskItemsListComponent.new(risk_results: @risk_results) %>
  <% end %>

  <div class="print-break"></div>
  <%= render RightsReportSectionComponent.new(report: @report, property: @property) %>

  <div class="print-break"></div>
  <%= render ConsultationGuideComponent.new(risk_results: @risk_results) %>
  <%= render LegalDisclaimerComponent.new %>
</div>
```

- [ ] **Step 7: Update controller with PDF response**

Replace the full content of `app/controllers/inspections/grades_controller.rb`:

```ruby
module Inspections
  class GradesController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @rating = InspectionRatingService.call(property: @property, user: current_user)
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)
      @budget_setting = current_user.budget_setting

      @results_by_tab = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
        .group_by { |r| r.inspection_item.tab }

      @risk_results = @property.inspection_results
        .where(has_risk: true, user: current_user)
        .includes(:inspection_item)
        .order("inspection_items.tab, inspection_items.tab_position")

      respond_to do |format|
        format.html
        format.pdf { send_report_pdf }
      end
    end

    private

    def send_report_pdf
      html = render_to_string(template: "inspections/grades/show", formats: [:pdf], layout: "report_pdf")
      pdf_binary = PdfExportService.call(html: html)
      filename = "경매분석리포트_#{@property.case_number}_#{Date.current}.pdf"
      send_data pdf_binary, filename: filename, type: "application/pdf", disposition: "attachment"
    end
  end
end
```

- [ ] **Step 8: Add controller test for PDF format**

Add to `test/controllers/inspections/grades_controller_test.rb`:

```ruby
test "show responds to PDF format" do
  get property_inspections_grade_url(@property, format: :pdf)
  assert_response :success
  assert_equal "application/pdf", response.content_type
end
```

- [ ] **Step 9: Run all tests**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 10: Commit**

```bash
git add app/services/pdf_export_service.rb test/services/pdf_export_service_test.rb app/views/layouts/report_pdf.html.erb app/views/inspections/grades/show.pdf.erb app/controllers/inspections/grades_controller.rb test/controllers/inspections/grades_controller_test.rb
git commit -m "feat: add PdfExportService and PDF export to grade controller

Playwright-based HTML→PDF conversion with inlined Tailwind CSS.
Dedicated report_pdf layout for clean print output.
GET /properties/:id/inspections/grade.pdf triggers download."
```

---

### Task 7: Docker and infrastructure

**Files:**
- Modify: `Dockerfile`

- [ ] **Step 1: Update Dockerfile**

In the `Dockerfile`, add Chromium and Korean fonts to the **base** stage (before the `FROM base AS build` line). Locate the existing `RUN apt-get update` block in the `FROM base` stage and update it:

```dockerfile
# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 chromium fonts-noto-cjk && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

Also add the environment variable to the `ENV` block:

```dockerfile
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="/usr/bin/chromium"
```

- [ ] **Step 2: Verify Docker build (optional — local test)**

Run: `docker build -t real_estate_auction_v2 . 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "chore(docker): add Chromium and Korean fonts for PDF export"
```

---

### Task 8: Full integration verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass, no regressions

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses (fix any that appear)

- [ ] **Step 3: Run security scan**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings

- [ ] **Step 4: Manual browser verification**

Run: `bin/dev`

1. Navigate to a property with analysis results → click 최종등급 tab
2. Verify all 11 sections render in correct order
3. Verify PropertyInfoComponent shows correct property data
4. Verify ReportBudgetComponent shows budget or "예산 설정을 먼저 완료해주세요"
5. Verify BidOpinionComponent shows correct verdict + key figures
6. Verify ConsultationGuideComponent shows (or is hidden if no risks)
7. Click "PDF 다운로드" button → verify PDF downloads with Korean text
8. Open PDF → verify layout is clean, no dark mode, page breaks work

- [ ] **Step 5: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: address integration issues from manual testing"
```
